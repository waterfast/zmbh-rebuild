class_name Hero1Bullet
extends Area2D
## 悟空外放法术的旧图集和碰撞帧，由新版 HitData 完成结算。

var payload: HitData
var animation_name: StringName = &"hyjj"
var _hit_targets: Dictionary = {}

@onready var _shape: CollisionShape2D = $HitBox
@onready var _player: AnimationPlayer = $BulletPlayer

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	_player.animation_finished.connect(func(_name: StringName) -> void: queue_free())
	_player.play(animation_name)
	_player.advance(0.0)

func _physics_process(_delta: float) -> void:
	if _shape.disabled:
		_hit_targets.clear()
		return
	for area in get_overlapping_areas():
		_on_area_entered(area)

func _on_area_entered(area: Area2D) -> void:
	if _shape.disabled or not area is Hurtbox or payload == null:
		return
	var target: Combatant = area.combatant
	if target == null or target.team == payload.team or not target.health.is_alive():
		return
	var id := target.get_instance_id()
	if _hit_targets.has(id):
		return
	_hit_targets[id] = true
	CombatResolver.resolve(payload, target)
