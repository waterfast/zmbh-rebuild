class_name ActorController
extends Node

@export var actor: CombatActor
var enabled: bool = true:
	set(value):
		enabled = value
		if not enabled and is_instance_valid(actor):
			actor.clear_command()
var command := ActorCommand.new()

func _ready() -> void:
	process_physics_priority = -10

func submit() -> void:
	if enabled and is_instance_valid(actor):
		actor.submit_command(command)
