class_name SpellBurst
extends Node2D
## 已释放的连续地面法术共享伤害快照；随关卡回收，不使用脱离场景的定时回调。
var packed: PackedScene
var payload: HitData
var facing := 1.0
var reverse_visual := false
var fixed_visual_facing := 0.0
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
	attack.facing = fixed_visual_facing if fixed_visual_facing != 0.0 else (-facing if reverse_visual else facing)
	var offset: Vector2 = offsets[next_index]
	attack.position = position + Vector2(offset.x * facing, offset.y)
	var requested_scale: Variant = scales[next_index]
	attack.scale = requested_scale if requested_scale is Vector2 else Vector2.ONE * float(requested_scale)
	get_parent().add_child(attack)
	next_index += 1
