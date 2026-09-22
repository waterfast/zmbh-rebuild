class_name OriginalCombatCatalog
extends RefCounted
## 原作伤害表达式以受限算术树保存；没有运行时 eval 和旧全局依赖。
static var _hits: Dictionary = {}
static var _monsters: Dictionary = {}
const BASE := {
	1: [[80,50],[50,15],[8,4],[10,1],[10,1]],
	2: [[50,30],[100,30],[15,6],[10,1],[10,1]],
	3: [[120,60],[25,10],[15,4],[15,1],[15,1]],
	4: [[70,40],[70,20],[15,4],[5,1],[5,1]],
	5: [[80,40],[50,20],[10,4],[8,1],[8,1]],
}
const STATS := [&"max_hp", &"max_mp", &"attack", &"defense", &"magic_defense"]
static func apply_character(actor: CombatActor, character: int, level: int) -> void:
	var rows: Array = BASE.get(character, BASE[2])
	for index in STATS.size():
		var stat: StringName = STATS[index]
		var amount: float = rows[index][0] + rows[index][1] * (level - 1)
		actor.combatant.stats.set_modifier(&"level", stat, amount - float(actor.definition.get(stat)))
	actor.combatant.stats.set_modifier(&"level", &"level", level - actor.definition.level)

static func monster(id: int, variables: Dictionary = {}) -> StatDefinition:
	if _monsters.is_empty():
		_monsters = JSON.parse_string(FileAccess.get_file_as_string("res://content/combat/monsters.json"))
	var stats := StatDefinition.new()
	stats.max_mp = 0
	for key: String in _monsters.get(str(id), {}):
		stats.set(key, evaluate(_monsters[str(id)][key], variables))
	return stats

static func hit(character: int, animation: StringName) -> Dictionary:
	if _hits.is_empty():
		_hits = JSON.parse_string(FileAccess.get_file_as_string("res://content/combat/character_hits.json"))
	var name := String(animation)
	var aliases := {"hit1_1":"hit1", "hit2_1":"hit2", "hit3_1":"hit3", "qlj_1":"qlj", "dcj_1":"dcj", "tkj_1":"tkj", "mmw_1":"mmw", "zq_1":"zq", "smb_1":"smb", "mbyj":"lhsq"}
	var rows: Dictionary = _hits.get(str(character), {})
	return rows.get(name, rows.get(aliases.get(name, name), {}))

static func payload(actor: CombatActor, definition: AbilityDefinition, fallback_scale: float = 1.0) -> HitData:
	var row := hit(definition.character_id, definition.animation)
	var power := actor.combatant.stats.value(&"attack") * fallback_scale
	if not row.is_empty():
		power = evaluate(row.power, {"attack": actor.combatant.stats.value(&"attack"), "max_hp": actor.combatant.health.maximum, "skill_level": definition.learned_level + 1, "passive_level": definition.passive_level})
	var result := HitData.from_attacker(actor.combatant, power)
	if not row.is_empty():
		result.damage_type = int(row.damage_type) as HitData.DamageType
	return result

static func evaluate(value: Variant, variables: Dictionary, rng: RandomNumberGenerator = null) -> float:
	if value is int or value is float:
		return float(value)
	if value.has("integer"):
		return int(evaluate(value.integer, variables, rng))
	if value.has("variable"):
		return float(variables.get(value.variable, 1 if value.variable == "up_power" else 0))
	if value.has("random"):
		var low := evaluate(value.min, variables, rng)
		var high := evaluate(value.max, variables, rng)
		if value.random == "randi_range":
			return rng.randi_range(int(low), int(high)) if rng != null else randi_range(int(low), int(high))
		return rng.randf_range(low, high) if rng != null else randf_range(low, high)
	var left := evaluate(value.left, variables, rng)
	var right := evaluate(value.right, variables, rng)
	match value.operation:
		"Add": return left + right
		"Sub": return left - right
		"Mult": return left * right
		"Div": return left / right if right != 0 else 0.0
	return 0.0
