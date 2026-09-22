class_name HealEffect
extends AbilityEffect

@export var flat: float = 0.0
@export var maximum_ratio: float = 0.2
@export var missing_ratio: float = 0.0

func execute(actor: Node2D, _definition: AbilityDefinition) -> void:
	var health: ActorHealth = actor.combatant.health
	health.heal(flat + health.maximum * maximum_ratio + (health.maximum - health.current) * missing_ratio)
