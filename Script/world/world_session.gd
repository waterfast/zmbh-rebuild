class_name WorldSession
extends Node2D
## 关卡是资源寿命边界：切换时先释放旧地图、角色及飞行物。

signal level_loaded(level: LevelDefinition)
signal level_unloaded

var definition: LevelDefinition
var geometry: Node2D
var actors: Node2D

func load_level(id: StringName) -> bool:
	if not String(id).is_valid_filename():
		return false
	var path := "res://content/world/%s.tres" % id
	if not ResourceLoader.exists(path):
		return false
	var next_definition := load(path) as LevelDefinition
	if next_definition == null or not ResourceLoader.exists(next_definition.geometry_path):
		return false
	if next_definition.drop_ids.is_empty():
		next_definition.drop_ids = _load_drop_ids(next_definition.id)
	unload_level()
	# 引擎的弱资源缓存共享同关卡纹理，不在常驻目录或单例中缓存 PackedScene。
	var packed := load(next_definition.geometry_path) as PackedScene
	if packed == null:
		return false
	geometry = packed.instantiate() as Node2D
	if geometry == null:
		return false
	definition = next_definition
	add_child(geometry)
	actors = Node2D.new()
	actors.name = "Actors"
	add_child(actors)
	level_loaded.emit(definition)
	return true

func _load_drop_ids(id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/maps/level_previews.json"))
	if not source is Dictionary:
		return result
	var row: Variant = source.get(String(id), {})
	if not row is Dictionary:
		return result
	var drops: Array = row.get("LevelFall", []) as Array
	for item: Variant in drops:
		if item is String and not item.is_empty() and not result.has(StringName(item)):
			result.append(StringName(item))
	return result

func unload_level() -> void:
	if is_instance_valid(actors):
		remove_child(actors)
		actors.free()
	if is_instance_valid(geometry):
		remove_child(geometry)
		geometry.free()
	actors = null
	geometry = null
	definition = null
	level_unloaded.emit()

func get_stage_gate(stage: int) -> CollisionShape2D:
	if geometry == null:
		return null
	return geometry.get_node_or_null("wall/stop%d" % stage) as CollisionShape2D

func set_gate_open(stage: int, open: bool) -> void:
	var gate := get_stage_gate(stage)
	if gate != null:
		gate.set_deferred("disabled", open)

func add_actor(actor: Node2D, spawn_position: Vector2) -> bool:
	if actors == null:
		return false
	actors.add_child(actor)
	actor.position = spawn_position
	return true

func exit_position() -> Vector2:
	if geometry != null:
		var marker := geometry.get_node_or_null("exit") as Node2D
		if marker != null:
			return marker.global_position
	return definition.exit_position if definition != null else Vector2.ZERO
