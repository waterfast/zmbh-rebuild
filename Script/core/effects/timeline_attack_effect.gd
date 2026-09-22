class_name TimelineAttackEffect
extends AbilityEffect

@export_file("*.tscn") var scene_path: String
@export var offset := Vector2.ZERO
@export var power_scale: float = 1.0
@export var damage_type: HitData.DamageType = HitData.DamageType.MAGIC

func execute(actor: Node2D, definition: AbilityDefinition) -> void:
	if actor.get_parent() == null or scene_path.is_empty():
		return
	var scene := load(scene_path) as PackedScene
	if scene == null:
		return
	var attack = scene.instantiate()
	attack.payload = OriginalCombatCatalog.payload(actor, definition, power_scale)
	if OriginalCombatCatalog.hit(definition.character_id, definition.animation).is_empty():
		attack.payload.damage_type = damage_type
	attack.facing = actor.facing
	attack.position = actor.position + Vector2(offset.x * actor.facing, offset.y)
	actor.get_parent().add_child(attack)
