class_name CharacterActionTimeline
extends Node2D
## 原动画只写局部表现和命中形状；输入、状态与伤害结算仍由新版组件负责。
var actor: CombatActor
var definition: AbilityDefinition
var playback_speed := 1.0
var use_hitbox := false
var _revision: int
var _view: ActorView

func _ready() -> void:
	_revision = actor.action.revision
	_view = actor.get_node_or_null("ActorView")
	if _view != null:
		_view.hide()
		# 同一图集沿用新版脚底锚点，避免攻击瞬间角色上下跳动。
		if _view.body != null:
			$Action.position = _view.body.position
	scale.x = -1.0 if actor.facing > 0 else 1.0
	var hitbox: AnimatedAttackHitbox = $base_damagebox/HitBox
	if use_hitbox:
		hitbox.payload = OriginalCombatCatalog.payload(actor, definition, definition.power_scale)
	$Player.speed_scale = playback_speed
	$Player.play(definition.animation)
	$Player.advance(0)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(actor) or actor.action.revision != _revision:
		cancel()

func cancel() -> void:
	$base_damagebox/HitBox._spent = true
	if is_instance_valid(_view):
		_view.show()
	queue_free()

func _exit_tree() -> void:
	if is_instance_valid(_view):
		_view.show()
