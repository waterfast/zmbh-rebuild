class_name LocomotionState
extends RefCounted

enum State { IDLE, RUN, JUMP, FALL }
var current: State = State.IDLE

func update(grounded: bool, velocity: Vector2) -> void:
	if not grounded:
		current = State.JUMP if velocity.y < 0.0 else State.FALL
	else:
		current = State.RUN if absf(velocity.x) > 0.1 else State.IDLE
