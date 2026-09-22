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

func _ready() -> void:
	set_skin(skin_id)

func bind_states(action: ActionState, locomotion: LocomotionState) -> void:
	_action = action
	_locomotion = locomotion

func sync_facing(direction: float) -> void:
	_facing = direction

func _process(_delta: float) -> void:
	if actor != null:
		if _action_revision != actor.action.revision:
			_action_revision = actor.action.revision
			_animation = &""
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

func _exit_tree() -> void:
	_action = null
	_locomotion = null
