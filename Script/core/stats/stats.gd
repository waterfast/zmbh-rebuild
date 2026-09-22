class_name ActorStats
extends RefCounted

signal changed

var _definition: StatDefinition
var _modifiers: Dictionary = {}
var _cache: Dictionary = {}

func _init(definition: StatDefinition) -> void:
	_definition = definition

## 同一来源同一属性覆盖；不同来源相加。来源使用唯一标识，不持有装备对象。
func set_modifier(source: StringName, stat: StringName, flat: float, percent: float = 0.0) -> void:
	if not _modifiers.has(source):
		_modifiers[source] = {}
	_modifiers[source][stat] = Vector2(flat, percent)
	_cache.erase(stat)
	changed.emit()

func remove_source(source: StringName) -> void:
	if _modifiers.erase(source):
		_cache.clear()
		changed.emit()

func value(stat: StringName) -> float:
	if _cache.has(stat):
		return _cache[stat]
	var raw: Variant = _definition.get(stat)
	var base: float = float(raw) if raw != null else 0.0
	var flat := 0.0
	var percent := 0.0
	for source: StringName in _modifiers:
		var modifiers: Dictionary = _modifiers[source]
		var amount: Vector2 = modifiers.get(stat, Vector2.ZERO)
		flat += amount.x
		percent += amount.y
	var result := maxf(0.0, (base + flat) * (1.0 + percent))
	_cache[stat] = result
	return result
