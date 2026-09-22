class_name SpellBurst
extends Node2D
## 已释放的连续地面法术共享伤害快照；随关卡回收，不使用脱离场景的定时回调。
var packed: PackedScene
var payload: HitData
var facing := 1.0
var offsets: Array = []
var scales: Array = []
var interval := 0.2
var elapsed := 0.0
var next_index := 0
func _ready() -> void:
	_spawn()
func _physics_process(delta: float) -> void:
	elapsed += delta
	while next_index < offsets.size() and elapsed >= next_index * interval:
		_spawn()
	if next_index >= offsets.size():
		queue_free()
func _spawn() -> void:
	if next_index >= offsets.size():
		return
	var attack = packed.instantiate()
	attack.payload = payload
	attack.facing = facing
	var offset: Vector2 = offsets[next_index]
	attack.position = position + Vector2(offset.x * facing, offset.y)
	attack.scale = Vector2.ONE * float(scales[next_index])
	get_parent().add_child(attack)
	next_index += 1
