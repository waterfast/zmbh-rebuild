class_name AbilityDefinition
extends Resource

@export var id: StringName
@export var category: StringName = &"character"
@export var source_kind: StringName = &"character"
@export var display_name: String
@export_multiline var description: String
@export var learned_level: int = 1
@export var passive_level: int = 0
@export var character_id: int = 0
@export var legacy_id: StringName
@export var slot: int = 0
@export var passive: bool = false
@export var effects: Array[AbilityEffect] = []
@export var migration_status: String = "implemented"
@export_file("*.png") var icon_path: String
@export var mp_expression: Dictionary = {}
@export var mp_cost: float = 25.0
@export var cooldown: float = 2.4
@export var cast_duration: float = 0.3
@export var animation: StringName
@export var release_delay: float = 0.0
@export var power_scale: float = 0.55
@export var projectile_speed: float = 420.0
@export var projectile_lifetime: float = 1.8
@export var projectile_scene: PackedScene
