class_name ActorView
extends Node2D
## 只消费状态和朝向，不驱动移动、伤害或技能时序。

@export var skin_id: StringName = &"tang_sanzang"
@export var actor: CombatActor

var body: AnimatedSprite2D
var weapon: AnimatedSprite2D
var _action: ActionState
var _locomotion: LocomotionState
var _facing: float = 1.0
var _animation: StringName
var _foot_offset := Vector2.ZERO
var _is_hero: bool = false
var _faces_left: bool = true
var _action_revision: int = -1
var _status_timeline: CharacterActionTimeline
var _death_elapsed: float = 0.0
var _death_effect_spawned: bool = false

func _ready() -> void:
	set_skin(skin_id)
	if actor != null and actor.combatant != null:
		bind_actor(actor)

func bind_actor(source: CombatActor) -> void:
	actor = source
	_sync_corpse_lifetime()
	if not source.combatant.damaged.is_connected(_on_actor_damaged):
		source.combatant.damaged.connect(_on_actor_damaged)
	if not source.despawning.is_connected(_on_actor_despawning):
		source.despawning.connect(_on_actor_despawning)

func bind_states(action: ActionState, locomotion: LocomotionState) -> void:
	_action = action
	_locomotion = locomotion

func sync_facing(direction: float) -> void:
	_facing = direction

func _process(delta: float) -> void:
	if actor != null:
		_update_monster_death_effect(delta)
		if _action_revision != actor.action.revision:
			_action_revision = actor.action.revision
			_animation = &""
			_present_status_timeline()
		sync_facing(actor.facing)
		present(actor.action.current, actor.locomotion.current, actor.facing)
		return
	if _action != null and _locomotion != null:
		present(_action.current, _locomotion.current, _facing)

func set_skin(id: StringName) -> bool:
	var body_path := "res://presentation/skins/%s.tres" % id
	var weapon_path := ""
	if ResourceLoader.exists("res://presentation/skins/%s_body.tres" % id):
		body_path = "res://presentation/skins/%s_body.tres" % id
		weapon_path = "res://presentation/skins/%s_weapon.tres" % id
	if not ResourceLoader.exists(body_path):
		return false
	var frames := load(body_path) as SpriteFrames
	if frames == null:
		return false
	if body == null:
		body = AnimatedSprite2D.new()
		body.name = "Body"
		add_child(body)
	if weapon == null:
		weapon = AnimatedSprite2D.new()
		weapon.name = "Weapon"
		add_child(weapon)
	skin_id = id
	body.sprite_frames = frames
	_foot_offset = frames.get_meta(&"foot_offset", Vector2(0, -40))
	_is_hero = frames.get_meta(&"hero", false)
	_faces_left = frames.get_meta(&"faces_left", true)
	body.position = _foot_offset
	weapon.position = body.position
	weapon.sprite_frames = load(weapon_path) as SpriteFrames if not weapon_path.is_empty() and ResourceLoader.exists(weapon_path) else null
	weapon.visible = weapon.sprite_frames != null
	_sync_corpse_lifetime()
	_animation = &""
	present(ActionState.State.FREE, LocomotionState.State.IDLE, _facing)
	return true

func present(action_state: int, locomotion_state: int, facing: float) -> void:
	if body == null or body.sprite_frames == null:
		return
	_facing = facing
	# 原图集朝向与脚底锚点是皮肤元数据，和战斗角色尺寸解耦。
	var flip := facing > 0.0 if _faces_left else facing < 0.0
	body.flip_h = flip
	weapon.flip_h = flip
	body.position.x = -_foot_offset.x if flip else _foot_offset.x
	weapon.position = body.position
	var animation := _choose_animation(action_state, locomotion_state)
	if not body.sprite_frames.has_animation(animation):
		animation = &"wait"
	if animation == _animation:
		return
	_animation = animation
	body.stop()
	body.play(animation)
	weapon.visible = weapon.sprite_frames != null and weapon.sprite_frames.has_animation(animation)
	if weapon.sprite_frames != null and weapon.sprite_frames.has_animation(animation):
		weapon.stop()
		weapon.play(animation)

func _choose_animation(action_state: int, locomotion_state: int) -> StringName:
	if actor != null and action_state in [ActionState.State.ATTACK, ActionState.State.SKILL] and not actor.current_animation.is_empty():
		return actor.current_animation
	match action_state:
		ActionState.State.DEAD:
			return &"death"
		ActionState.State.HURT:
			return &"hurt"
		ActionState.State.ATTACK:
			return _attack_animation()
		ActionState.State.SKILL:
			return &"blb" if body.sprite_frames.has_animation(&"blb") else _attack_animation()
	match locomotion_state:
		LocomotionState.State.RUN:
			return &"run" if body.sprite_frames.has_animation(&"run") else &"walk"
		LocomotionState.State.JUMP:
			return &"jump1" if _is_hero else &"wait"
		LocomotionState.State.FALL:
			return &"drop" if _is_hero else &"wait"
	return &"wait"

func _attack_animation() -> StringName:
	return &"hit1" if body.sprite_frames.has_animation(&"hit1") else &"hit1_1"

func _present_status_timeline() -> void:
	if not _is_hero or actor == null:
		return
	if actor.action.current != ActionState.State.HURT and actor.action.current != ActionState.State.DEAD:
		return
	if is_instance_valid(_status_timeline):
		_status_timeline.cancel()
	var animation := &"death" if actor.action.current == ActionState.State.DEAD else &"hurt"
	_status_timeline = CharacterActionCatalog.present_status(actor, CharacterAbilityRegistry.character_id(skin_id), animation)

func _on_actor_damaged(amount: float, _hitstun: float) -> void:
	if amount <= 0.0 or actor == null or not is_instance_valid(actor.get_parent()):
		return
	if _is_hero:
		SpecialEffect.spawn(actor, &"RoleBeHit", actor.global_position, false, 1.0, Vector2.ONE, true)
	else:
		var effect := load("res://Scene/Effects/MonsterBeHit.tscn").instantiate() as MonsterHitEffect
		effect.top_level = true
		effect.z_index = 90
		actor.get_parent().add_child(effect)
		effect.global_position = actor.global_position

func _on_actor_despawning() -> void:
	_spawn_monster_death_effect()

func _update_monster_death_effect(delta: float) -> void:
	if _is_hero or actor.action.current != ActionState.State.DEAD or _death_effect_spawned:
		return
	_death_elapsed += delta
	# 原怪物死亡动画通常在 0.8 秒的方法帧生成粒子；短动画要赶在回收前播放。
	if _death_elapsed >= minf(0.8, maxf(0.0, actor.corpse_lifetime - 0.1)):
		_spawn_monster_death_effect()

func _spawn_monster_death_effect() -> void:
	if _is_hero or _death_effect_spawned or actor == null or not is_instance_valid(actor.get_parent()):
		return
	_death_effect_spawned = true
	SpecialEffect.spawn(actor.get_parent(), &"MonsterDeath", actor.global_position)

func _sync_corpse_lifetime() -> void:
	if actor == null or not actor.despawn_on_death or body == null or body.sprite_frames == null:
		return
	var frames := body.sprite_frames
	if not frames.has_animation(&"death"):
		return
	var duration := 0.0
	for index in frames.get_frame_count(&"death"):
		duration += frames.get_frame_duration(&"death", index) / maxf(1.0, frames.get_animation_speed(&"death"))
	actor.corpse_lifetime = maxf(0.7, duration)

func _exit_tree() -> void:
	_action = null
	_locomotion = null
