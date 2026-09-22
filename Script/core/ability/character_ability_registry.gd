class_name CharacterAbilityRegistry
extends RefCounted
## 角色是技能来源；技能定义仍由 AbilityCatalog 统一解析和缓存。

const SKIN_TO_CHARACTER := {
	&"hero_1": 1,
	&"tang_sanzang": 2,
	&"hero_2": 2,
	&"hero_3": 3,
	&"hero_4": 4,
	&"hero_5": 5,
}
const CHARACTER_TO_SKIN := {
	1: &"hero_1",
	2: &"tang_sanzang",
	3: &"hero_3",
	4: &"hero_4",
	5: &"hero_5",
}
const ACTIVE_ACTIONS: Array[StringName] = [&"ability_0", &"ability", &"ability_2", &"ability_3", &"ability_4"]

static func character_id(skin: StringName) -> int:
	return int(SKIN_TO_CHARACTER.get(skin, 2))

static func skin_id(character: int) -> StringName:
	return StringName(CHARACTER_TO_SKIN.get(character, &"tang_sanzang"))

static func register_actor(actor: CombatActor, skin: StringName, catalog: AbilityCatalog = null, learned: Variant = null) -> Array[StringName]:
	if actor == null or actor.abilities == null:
		return []
	var ability_catalog := catalog if catalog != null else AbilityCatalog.new()
	actor.abilities.remove_source(&"character")
	var definitions := ability_catalog.for_character(character_id(skin))
	var active_ids: Array[StringName] = []
	for definition: AbilityDefinition in definitions:
		if learned is Dictionary and int(learned.get(String(definition.id), 0)) <= 0:
			continue
		var runtime := CharacterActionCatalog.configure(definition, character_id(skin)).duplicate(true) as AbilityDefinition
		if learned is Dictionary:
			runtime.learned_level = int(learned.get(String(definition.id), 0))
		if not runtime.mp_expression.is_empty():
			runtime.mp_cost = OriginalCombatCatalog.evaluate(runtime.mp_expression, {"skill_level": runtime.learned_level})
		for passive_definition: AbilityDefinition in definitions:
			if passive_definition.passive and learned is Dictionary:
				runtime.passive_level = int(learned.get(String(passive_definition.id), 0))
		actor.abilities.grant(runtime, &"character", &"character", &"character")
		if not definition.passive:
			active_ids.append(definition.id)
	if actor.normal_attack == null or character_id(skin) != 2:
		actor.normal_attack = _normal_attack(character_id(skin))
	var input := actor.get_node_or_null("PlayerInput")
	if input != null and input.source is ActionInputSource:
		input.source.slots.clear()
		for index in mini(active_ids.size(), ACTIVE_ACTIONS.size()):
			input.source.slots[ACTIVE_ACTIONS[index]] = active_ids[index]
	return active_ids

static func resolve_passive(id: StringName) -> PassiveDefinition:
	var definition := PassiveDefinition.new()
	definition.id = id
	definition.category = &"equipment"
	definition.source_kind = &"equipment"
	definition.lifesteal = 0.05
	definition.cooldown = 1.0
	return definition

static func resolve_ability(id: StringName) -> AbilityDefinition:
	return AbilityCatalog.new().runtime_resolve(id)

static func _normal_attack(character: int) -> AbilityDefinition:
	var definition := AbilityDefinition.new()
	definition.id = StringName("character_%d_normal" % character)
	definition.category = &"character"
	definition.source_kind = &"character"
	definition.display_name = "普通攻击"
	definition.character_id = character
	definition.cast_duration = 0.35
	definition.cooldown = 0.35
	definition.animation = &"hit1_1" if character == 4 else &"hit1"
	var effect := MeleeEffect.new()
	effect.power_scale = 1.0
	effect.lifetime = 0.16
	definition.effects = [effect]
	return CharacterActionCatalog.configure(definition, character)
