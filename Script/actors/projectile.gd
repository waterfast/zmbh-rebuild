class_name CombatProjectile
extends Hitbox

var speed: float = 420.0
var direction: float = 1.0

func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	super._physics_process(delta)
