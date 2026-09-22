class_name ProjectileEffect
extends AbilityEffect

@export_file("*.tscn") var scene_path: String = "res://actors/projectile.tscn"
@export var power_scale: float = 1.0
@export var speed: float = 420.0
@export var lifetime: float = 1.8
@export var offset: Vector2 = Vector2(32.0, -24.0)
@export var damage_type: HitData.DamageType = HitData.DamageType.PHYSICAL
@export var buff: BuffDefinition

func execute(actor: Node2D, definition: AbilityDefinition) -> void:
	var scene: PackedScene = load(scene_path)
	if scene == null or actor.get_parent() == null:
		return
	var projectile = scene.instantiate()
	projectile.payload = OriginalCombatCatalog.payload(actor, definition, power_scale)
	if OriginalCombatCatalog.hit(definition.character_id, definition.animation).is_empty():
		projectile.payload.damage_type = damage_type
	projectile.payload.buff = buff
	projectile.speed = speed
	projectile.direction = actor.facing
	projectile.lifetime = lifetime
	projectile.single_target = true
	actor.get_parent().add_child(projectile)
	projectile.global_position = actor.global_position + Vector2(offset.x * actor.facing, offset.y)
