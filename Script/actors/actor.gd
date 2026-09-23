class_name CombatActor
extends CharacterBody2D
## 组合入口：控制器提交意图，Actor 安排更新顺序，组件执行各自规则。

signal despawning

const MELEE_SCENE = preload("res://actors/melee.tscn")

@export var definition: StatDefinition
@export var team: int = 1
@export var starting_ability: AbilityDefinition
@export var normal_attack: AbilityDefinition
@export var body_color: Color = Color.CORNFLOWER_BLUE
@export var despawn_on_death: bool = false
@export var corpse_lifetime: float = 0.7
@export var debug_draw: bool = true

var combatant: Combatant
var combo := AttackCombo.new()
var motor := CharacterMotor.new()
var locomotion := LocomotionState.new()
var action := ActionState.new()
var abilities: AbilityController
var facing: float = 1.0
var move_intent: float = 0.0
var jump_intent: bool = false
var _attack_intent: bool = false
var _ability_intent: StringName = &""
var _corpse_time: float = 0.0
var _melee: Hitbox
var current_animation: StringName
var _normal_cooldown: float = 0.0
var _action_timeline: CharacterActionTimeline
var _pending_action: AbilityDefinition
var _release_remaining: float = 0.0

@onready var hurtbox: Hurtbox = $Hurtbox

func _ready() -> void:
	combatant = Combatant.new(definition, team)
	abilities = AbilityController.new(combatant.stats.value(&"max_mp"))
	abilities.bind_stats(combatant.stats)
	hurtbox.combatant = combatant
	combatant.damaged.connect(_on_damaged)
	combatant.health.died.connect(_on_died)
	var view := get_node_or_null("ActorView") as ActorView
	if view != null:
		view.bind_actor(self)
	abilities.cast.connect(_on_cast)
	if starting_ability != null:
		abilities.grant(starting_ability, &"character")

func _physics_process(delta: float) -> void:
	_advance_pending_action(delta)
	action.tick(delta)
	combo.tick(delta)
	_normal_cooldown = maxf(0.0, _normal_cooldown - delta)
	abilities.tick(delta)
	if _attack_intent:
		attack()
	if not _ability_intent.is_empty():
		use_ability(_ability_intent)
	_attack_intent = false
	_ability_intent = &""
	combatant.tick(delta)
	var can_move := action.can_move()
	var direction := move_intent if can_move else 0.0
	if direction != 0.0:
		facing = signf(direction)
	motor.step(self, direction, jump_intent and can_move, combatant.stats.value(&"move_speed"), delta)
	jump_intent = false
	locomotion.update(is_on_floor(), velocity)
	if not combatant.health.is_alive() and despawn_on_death:
		_corpse_time += delta
		if _corpse_time >= corpse_lifetime:
			despawning.emit()
			queue_free()
			despawn_on_death = false
	if debug_draw:
		queue_redraw()

func submit_command(command: ActorCommand) -> void:
	move_intent = clampf(command.movement, -1.0, 1.0)
	jump_intent = command.jump
	_attack_intent = command.attack
	_ability_intent = command.ability

func clear_command() -> void:
	move_intent = 0.0
	jump_intent = false
	_attack_intent = false
	_ability_intent = &""

func request_dash(speed: float, duration: float) -> void:
	motor.dash(facing * speed, duration)

func register_attack(hitbox: Hitbox) -> void:
	if is_instance_valid(_melee):
		_melee.cancel()
	_melee = hitbox

func attack() -> bool:
	if normal_attack != null:
		var attack_definition := combo.next(normal_attack)
		if _normal_cooldown > 0.0 or not action.try_start(ActionState.State.ATTACK, attack_definition.cast_duration):
			return false
		_normal_cooldown = attack_definition.cooldown
		combo.advance(attack_definition.cast_duration)
		_schedule_action(attack_definition)
		return true
	if not action.try_start(ActionState.State.ATTACK, 0.35):
		return false
	current_animation = &""
	_melee = MELEE_SCENE.instantiate()
	_melee.payload = HitData.from_attacker(combatant, combatant.stats.value(&"attack"))
	_melee.position = Vector2(facing * 38.0, -24.0)
	_melee.get_node("Visual").visible = debug_draw
	add_child(_melee)
	return true

func use_ability(id: StringName, category: StringName = &"") -> bool:
	var grant := abilities.get_grant(id, category)
	if grant != null:
		category = grant.category
	var request := SkillTriggerRequest.new(id, category, &"", action, self)
	return abilities.try_trigger(request)

func _on_cast(data: AbilityDefinition) -> void:
	_schedule_action(data)

func _schedule_action(data: AbilityDefinition) -> void:
	if is_instance_valid(_action_timeline):
		_action_timeline.cancel()
	current_animation = data.animation
	_action_timeline = CharacterActionCatalog.present(self, data)
	if data.release_delay <= 0.0:
		AbilityExecutor.execute(data, self)
	else:
		_pending_action = data
		_release_remaining = data.release_delay

func _advance_pending_action(delta: float) -> void:
	if _pending_action == null:
		return
	if action.current != ActionState.State.ATTACK and action.current != ActionState.State.SKILL:
		_pending_action = null
		return
	_release_remaining -= delta
	if _release_remaining <= 0.0:
		var data := _pending_action
		_pending_action = null
		AbilityExecutor.execute(data, self)

func _on_damaged(_amount: float, hitstun: float) -> void:
	if hitstun > 0.0 and combatant.health.is_alive():
		_pending_action = null
		combo.reset()
		action.hurt(hitstun)
		motor.stop_impulses()
		_cancel_melee()

func _on_died() -> void:
	_pending_action = null
	action.die()
	motor.stop_impulses()
	clear_command()
	combatant.buffs.clear()
	_cancel_melee()
	hurtbox.set_deferred("monitorable", false)

func _cancel_melee() -> void:
	if is_instance_valid(_action_timeline):
		_action_timeline.cancel()
		_action_timeline = null
	if is_instance_valid(_melee):
		_melee.cancel()
		_melee = null

func _draw() -> void:
	if combatant == null or not debug_draw:
		return
	var color := body_color
	if action.current == ActionState.State.DEAD:
		color = Color.DIM_GRAY
	elif action.current == ActionState.State.HURT:
		color = Color.SALMON
	draw_rect(Rect2(-14, -48, 28, 48), color)
	draw_line(Vector2(0, -32), Vector2(facing * 22, -32), Color.WHITE, 3.0)
	draw_rect(Rect2(-22, -61, 44, 5), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(-22, -61, 44 * combatant.health.current / combatant.health.maximum, 5), Color.LIME_GREEN)
	if combatant.buffs.has_tag(&"super_armor"):
		draw_arc(Vector2(0, -24), 33.0, 0, TAU, 24, Color.GOLD, 2.0)
