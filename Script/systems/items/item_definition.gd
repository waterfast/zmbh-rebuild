class_name ItemDefinition
extends RefCounted
## 定义仅由目录缓存持有；实例不引用定义，淘汰缓存不会被背包间接阻止。

const STAT_NAMES := {
	"SHp": &"max_hp", "SMp": &"max_mp", "power": &"attack", "Def": &"defense",
	"Mdef": &"magic_defense", "Crit": &"critical_chance", "Miss": &"dodge_chance",
	"R_hp": &"hp_regen", "R_mp": &"mp_regen", "vampirism": &"lifesteal",
	"Lucky": &"luck", "Toughness": &"toughness", "Htarget": &"accuracy",
	"CritReduce": &"critical_reduction", "ar": &"armor_penetration", "sp": &"magic_penetration",
}
const SLOT_NAMES := {"武器": &"weapon", "防具": &"armor", "饰品": &"accessory", "法宝": &"relic", "翅膀": &"wings", "时装": &"costume", "头衔": &"title"}

var id: StringName
var _data: Dictionary

func _init(data: Dictionary) -> void:
	_data = data.duplicate(true)
	id = StringName(data.get("id", ""))

func metadata() -> Dictionary:
	return _data.get("legacy", {}).duplicate(true)

func slot() -> StringName:
	return SLOT_NAMES.get(_data.get("legacy", {}).get("类型", ""), &"")

func kind() -> StringName:
	var configured: String = str(_data.get("kind", ""))
	if not configured.is_empty():
		return StringName(configured)
	return slot()

func category() -> StringName:
	return StringName(_data.get("category", kind()))

func skill_ids() -> Array:
	var configured: Array = _data.get("skill_ids", _data.get("ability_ids", [])).duplicate()
	if not configured.is_empty():
		return configured
	if slot() == &"relic":
		return RelicAbilityRegistry.ids_for_item(id)
	return []

func ability_ids() -> Array:
	return skill_ids()

func passive_ids() -> Array:
	return _data.get("passive_ids", []).duplicate()

func roll(rng: RandomNumberGenerator) -> Dictionary:
	var result: Dictionary = {}
	for key: String in _data.get("legacy", {}):
		var value: Variant = _data.legacy[key]
		if value is Dictionary and (value.has("random") or value.has("operation")):
			result[key] = _evaluate(value, rng)
	return result

func valid_rolls(rolls: Dictionary) -> bool:
	var expected: Dictionary = {}
	for key: String in _data.get("legacy", {}):
		var value: Variant = _data.legacy[key]
		if value is Dictionary and (value.has("random") or value.has("operation")):
			expected[key] = true
			if not rolls.has(key) or not (rolls[key] is int or rolls[key] is float) or not is_finite(float(rolls[key])):
				return false
			var bounds := _bounds(value)
			if float(rolls[key]) < bounds.x - 0.00001 or float(rolls[key]) > bounds.y + 0.00001:
				return false
			if value.get("random") == "randi_range" and float(rolls[key]) != floorf(float(rolls[key])):
				return false
			if value.has("step") and not is_equal_approx(float(rolls[key]), snappedf(float(rolls[key]), float(value.step))):
				return false
	return expected.size() == rolls.size()

func stats(instance: ItemInstance) -> Dictionary:
	var legacy: Dictionary = _data.get("legacy", {})
	var result: Dictionary = {}
	var enhancements: Dictionary = legacy.get("强化属性", {})
	for key: String in STAT_NAMES:
		var amount := float(instance.rolls.get(key, legacy.get(key, 0.0)))
		var growth := 1.0
		if slot() == &"relic":
			growth = float(instance.rolls.get("成长率", legacy.get("成长率", 1.0))) if key in ["SHp", "SMp", "power", "Def", "Mdef"] else 0.0
			var element: String = {"SHp": "火", "SMp": "水", "power": "金", "Def": "土", "Mdef": "土"}.get(key, "")
			if instance.elements.has(element):
				growth += 1.0
		if not slot().is_empty():
			amount += float(enhancements.get(key, 0.0)) * instance.enhancement * growth
		# 原表用百分数，新战斗内核用比例；转换只发生在边界，不改原始配置和随机结果。
		if key in ["Crit", "Miss", "vampirism", "Toughness", "Htarget", "CritReduce"]:
			amount /= 100.0
		if not is_zero_approx(amount):
			result[STAT_NAMES[key]] = amount
	return result

func _bounds(value: Variant) -> Vector2:
	if not value is Dictionary:
		return Vector2(float(value), float(value))
	if value.has("random"):
		var minimum := float(value.min)
		var maximum := float(value.max)
		if value.has("step"):
			minimum = snappedf(minimum, float(value.step))
			maximum = snappedf(maximum, float(value.step))
		return Vector2(minimum, maximum)
	var left := _bounds(value.left)
	var right := _bounds(value.right)
	match value.operation:
		"Add": return Vector2(left.x + right.x, left.y + right.y)
		"Sub": return Vector2(left.x - right.y, left.y - right.x)
		"Mult":
			var products := [left.x * right.x, left.x * right.y, left.y * right.x, left.y * right.y]
			return Vector2(products.min(), products.max())
		"Div":
			var quotients := [left.x / right.x, left.x / right.y, left.y / right.x, left.y / right.y]
			return Vector2(quotients.min(), quotients.max())
	return Vector2.ZERO

func _evaluate(value: Variant, rng: RandomNumberGenerator) -> float:
	if not value is Dictionary:
		return float(value)
	if value.has("random"):
		var amount: float = rng.randi_range(int(value.min), int(value.max)) if value.random == "randi_range" else rng.randf_range(float(value.min), float(value.max))
		return snappedf(amount, float(value.step)) if value.has("step") else amount
	var left := _evaluate(value.left, rng)
	var right := _evaluate(value.right, rng)
	match value.operation:
		"Add": return left + right
		"Sub": return left - right
		"Mult": return left * right
		"Div": return left / right
	return 0.0
