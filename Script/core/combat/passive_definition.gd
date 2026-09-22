class_name PassiveDefinition
extends Resource

enum Trigger { ON_HIT, ON_DAMAGED }
@export var id: StringName
@export var category: StringName = &"equipment"
@export var source_kind: StringName = &"equipment"
@export var trigger: Trigger = Trigger.ON_HIT
@export_range(0.0, 1.0) var chance: float = 1.0
@export var lifesteal: float = 0.0
@export var heal_flat: float = 0.0
@export var buff: BuffDefinition
@export var buff_target_self: bool = true
@export var cooldown: float = 0.0
