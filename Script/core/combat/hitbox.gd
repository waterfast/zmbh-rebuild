class_name Hitbox
extends Area2D

signal landed

var payload: HitData
var lifetime: float = 0.12
var single_target: bool = false
var _hit_targets: Dictionary = {}
var _spent: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if _spent or not area is Hurtbox or payload == null:
		return
	var target: Combatant = area.combatant
	if target == null or target.team == payload.team or not target.health.is_alive():
		return
	var target_id := target.get_instance_id()
	if _hit_targets.has(target_id):
		return
	_hit_targets[target_id] = true
	CombatResolver.resolve(payload, target)
	landed.emit()
	if single_target:
		_spent = true
		queue_free()

func cancel() -> void:
	# queue_free 在帧末执行；立刻阻止这一帧尚未派发的碰撞回调。
	_spent = true
	queue_free()
