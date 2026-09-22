class_name LevelDefinition
extends Resource
## 路径索引不强持有关卡贴图；只有进入当前关卡才加载其 PackedScene。

@export var id: StringName
@export var display_name: String
@export_file("*.tscn") var geometry_path: String
@export var spawn_position: Vector2 = Vector2(180, 300)
@export var camera_bounds: Rect2 = Rect2(0, 0, 4800, 540)
@export var exit_position: Vector2 = Vector2(4202, 429)
@export var next_level_id: StringName
@export var drop_ids: Array[StringName] = []
@export var enemy_positions: PackedVector2Array
@export var waves: Array[Dictionary] = []
@export_range(1, 32) var maximum_active_enemies: int = 8
