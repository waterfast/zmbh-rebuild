class_name Hurtbox
extends Area2D

var combatant: Combatant

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	monitoring = false
