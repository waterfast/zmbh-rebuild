class_name PlayerProgression
extends RefCounted

signal changed
signal level_gained(level: int)

var level: int = 1
var experience: int = 0
var gold: int = 0
var cleared_levels: Array[String] = []

func required_experience() -> int:
	return 60 + (level - 1) * 40

func reward(xp: int, coins: int) -> void:
	experience += maxi(0, xp)
	gold += maxi(0, coins)
	while level < 100 and experience >= required_experience():
		experience -= required_experience()
		level += 1
		level_gained.emit(level)
	changed.emit()

func spend(coins: int) -> bool:
	if coins < 0 or gold < coins:
		return false
	gold -= coins
	changed.emit()
	return true

func complete_level(id: String) -> void:
	if not cleared_levels.has(id):
		cleared_levels.append(id)
		changed.emit()

func serialize() -> Dictionary:
	return {"level": level, "experience": experience, "gold": gold, "cleared_levels": cleared_levels.duplicate()}

func restore(data: Dictionary) -> bool:
	if not data.get("cleared_levels", []) is Array:
		return false
	var restored: Array[String] = []
	for id: Variant in data.get("cleared_levels", []):
		if not id is String or id.length() > 80:
			return false
		if not restored.has(id):
			restored.append(id)
	for key: String in ["level", "experience", "gold"]:
		if not (data.get(key, 0) is int or data.get(key, 0) is float):
			return false
	level = clampi(int(data.get("level", 1)), 1, 100)
	experience = clampi(int(data.get("experience", 0)), 0, 10000000)
	gold = clampi(int(data.get("gold", 0)), 0, 1000000000)
	cleared_levels = restored
	changed.emit()
	return true
