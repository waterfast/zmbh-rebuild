class_name SpellBurstEffect
extends AbilityEffect
@export var scene_path: String
var offsets: Array = []
var scales: Array = []
var power_scale := 1.0
func execute(actor: Node2D, definition: AbilityDefinition) -> void:
	var burst := SpellBurst.new()
	burst.packed = load(scene_path)
	burst.payload = OriginalCombatCatalog.payload(actor, definition, power_scale)
	burst.facing = actor.facing
	burst.offsets = offsets
	burst.scales = scales
	burst.position = actor.position
	actor.get_parent().add_child(burst)
