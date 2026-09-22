class_name MeleeEffect
extends AbilityEffect

@export_file("*.tscn") var scene_path: String = "res://actors/melee.tscn"
@export var power_scale: float = 1.0
@export var lifetime: float = 0.16
@export var offset: Vector2 = Vector2(38.0, -24.0)
@export var size_scale: Vector2 = Vector2.ONE
@export var damage_type: HitData.DamageType = HitData.DamageType.PHYSICAL
@export var buff: BuffDefinition

func execute(actor: Node2D, definition: AbilityDefinition) -> void:
	var scene: PackedScene = load(scene_path)
	if scene == null:
		return
	var hitbox: Hitbox = scene.instantiate()
	hitbox.payload = OriginalCombatCatalog.payload(actor, definition, power_scale)
	if OriginalCombatCatalog.hit(definition.character_id, definition.animation).is_empty():
		hitbox.payload.damage_type = damage_type
	hitbox.payload.buff = buff
	hitbox.lifetime = lifetime
	hitbox.position = Vector2(actor.facing * offset.x, offset.y)
	hitbox.scale = size_scale
	actor.add_child(hitbox)
	if actor.has_method("register_attack"):
		actor.register_attack(hitbox)
