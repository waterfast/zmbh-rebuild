class_name ActorHealth
extends RefCounted

signal changed(current: float, maximum: float)
signal died

var maximum: float
var current: float

func _init(max_hp: float) -> void:
	maximum = maxf(1.0, max_hp)
	current = maximum

func is_alive() -> bool:
	return current > 0.0

func set_maximum(amount: float) -> void:
	var updated := maxf(1.0, amount)
	if is_equal_approx(updated, maximum):
		return
	maximum = updated
	current = minf(current, maximum)
	changed.emit(current, maximum)

func damage(amount: float) -> float:
	if not is_alive() or amount <= 0.0:
		return 0.0
	var applied := minf(current, amount)
	current -= applied
	changed.emit(current, maximum)
	if not is_alive():
		died.emit()
	return applied

func heal(amount: float) -> void:
	if not is_alive() or amount <= 0.0:
		return
	current = minf(maximum, current + amount)
	changed.emit(current, maximum)
