class_name DashEffect
extends AbilityEffect

@export var speed: float = 650.0
@export var duration: float = 0.18

func execute(actor: Node2D, _definition: AbilityDefinition) -> void:
	if actor.has_method("request_dash"):
		actor.request_dash(speed, duration)
