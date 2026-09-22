class_name SkillProgression
extends RefCounted
## 学习等级和键位属于存档；目录共享定义不接受运行时修改。

signal changed
const PASSIVE_NAMES := ["热血", "魔泉", "狂暴", "永恒", "辉煌", "敏锐"]
const PASSIVE_STATS := [&"max_hp", &"max_mp", &"critical_chance", &"hp_regen", &"mp_regen", &"accuracy"]
const PASSIVE_VALUES := [[0,200,300,400,500,600,700], [0,100,130,160,200,240,280], [0,2,3,4,5,6,7], [0,2,3,4,5,6,7], [0,2,3,4,5,6,7], [0,2,3,4,5,6,7]]
const CHARACTER_REQUIREMENTS := [0,8,14,19,24,30,33,35,37,39]
var levels: Dictionary = {}
var slots: Dictionary = {}
var passives: Dictionary = {}

func level(id: StringName) -> int:
	return int(levels.get(String(id), 0))

func cost(definition: AbilityDefinition) -> int:
	return 500 + 500 * level(definition.id) if definition.passive else 100 + (definition.slot - 1) * 300 + 500 * level(definition.id)

func learn(definition: AbilityDefinition, character: int, wallet: PlayerProgression) -> String:
	if definition == null or definition.character_id != character:
		return "技能不属于当前角色"
	var current := level(definition.id)
	if current >= (10 if definition.passive else 1):
		return "技能已经满级"
	if definition.passive and wallet.level < CHARACTER_REQUIREMENTS[current]:
		return "需达到%d级" % CHARACTER_REQUIREMENTS[current]
	if not wallet.spend(cost(definition)):
		return "灵魂不足"
	levels[String(definition.id)] = current + 1
	if not definition.passive and slots.size() < 5:
		for index in range(5):
			if not slots.has(str(index)):
				slots[str(index)] = String(definition.id)
				break
	changed.emit()
	return ""

func assign(index: int, definition: AbilityDefinition, character: int) -> bool:
	if index < 0 or index >= 5 or definition == null or definition.passive or definition.character_id != character or level(definition.id) == 0:
		return false
	for key: String in slots.keys():
		if slots[key] == String(definition.id):
			slots.erase(key)
	slots[str(index)] = String(definition.id)
	changed.emit()
	return true

func learn_passive(index: int, wallet: PlayerProgression) -> String:
	if index < 0 or index >= PASSIVE_NAMES.size():
		return "无效技能"
	var name: String = PASSIVE_NAMES[index]
	var current := int(passives.get(name, 0))
	if current >= 6:
		return "技能已经满级"
	if not wallet.spend((current + 1) * 5000):
		return "灵魂不足"
	passives[name] = current + 1
	changed.emit()
	return ""

func apply(actor: CombatActor, skin: StringName, catalog: AbilityCatalog) -> void:
	CharacterAbilityRegistry.register_actor(actor, skin, catalog, levels)
	var input := actor.get_node_or_null("PlayerInput")
	if input != null and input.source is ActionInputSource:
		input.source.slots.clear()
		for key: String in slots:
			var id := StringName(slots[key])
			if actor.abilities.has_ability(id):
				input.source.slots[CharacterAbilityRegistry.ACTIVE_ACTIONS[int(key)]] = id
	var blood_level := level(&"sx")
	actor.combatant.stats.set_modifier(&"character_passive", &"critical_chance", (4.0 + (blood_level - 1) * 1.6) / 100.0 if blood_level > 0 else 0.0)
	actor.combatant.stats.set_modifier(&"character_passive", &"lifesteal", 0.03 + (blood_level - 1) * 0.003 if blood_level > 0 else 0.0)
	actor.abilities.grants_changed.emit()
	for index in PASSIVE_NAMES.size():
		var amount: float = PASSIVE_VALUES[index][int(passives.get(PASSIVE_NAMES[index], 0))]
		if index in [2, 5]:
			amount /= 100.0
		actor.combatant.stats.set_modifier(&"learned_passives", PASSIVE_STATS[index], amount)

func serialize() -> Dictionary:
	return {"levels": levels.duplicate(), "slots": slots.duplicate(), "passives": passives.duplicate()}

func restore(data: Dictionary, catalog: AbilityCatalog, character: int) -> bool:
	for field: String in ["levels", "slots", "passives"]:
		if not data.get(field, {}) is Dictionary:
			return false
	for id: String in data.get("levels", {}):
		var definition := catalog.resolve(StringName(id))
		var value: Variant = data.levels[id]
		if definition == null or definition.character_id != character or not _valid_level(value, 10 if definition.passive else 1):
			return false
	for name: String in data.get("passives", {}):
		if name not in PASSIVE_NAMES or not _valid_level(data.passives[name], 6):
			return false
	for key: String in data.get("slots", {}):
		if key not in ["0", "1", "2", "3", "4"] or not data.slots[key] is String:
			return false
		var definition := catalog.resolve(StringName(data.slots[key]))
		if definition == null or definition.passive or definition.character_id != character or int(data.get("levels", {}).get(data.slots[key], 0)) == 0:
			return false
	levels = data.get("levels", {}).duplicate()
	slots = data.get("slots", {}).duplicate()
	passives = data.get("passives", {}).duplicate()
	return true

func _valid_level(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= 0 and value <= maximum
