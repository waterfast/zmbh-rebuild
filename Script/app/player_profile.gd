class_name PlayerProfile
extends RefCounted
## 长期数据与当前角色分离，切图只销毁战斗对象，不复制整份装备定义。

var battle_relic: StringName = &""
var skills := SkillProgression.new()
var _actor: WeakRef

var content := ContentRegistry.new()
var catalog: ItemCatalog
var recipes := RecipeCatalog.new()
var alchemy: AlchemyService
var ability_catalog: AbilityCatalog
var inventory: ItemInventory
var progression := PlayerProgression.new()
var quests := QuestJournal.new()
var equipment: EquipmentLoadout
var selected_skin: StringName = &"tang_sanzang"
var last_level: StringName = &"level_1"
var _equipped: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	skills.changed.connect(_apply_skills)
	catalog = content.items
	ability_catalog = content.abilities
	inventory = ItemInventory.new(catalog)
	alchemy = AlchemyService.new(inventory, progression, recipes, _rng)
	_rng.randomize()
	for id: String in ["first_steps", "journey"]:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/quests/%s.json" % id))
		if data is Dictionary:
			quests.register(data)

func start_new() -> void:
	detach_actor()
	selected_skin = &"tang_sanzang"
	last_level = &"level_1"
	inventory = ItemInventory.new(catalog)
	progression = PlayerProgression.new()
	alchemy = AlchemyService.new(inventory, progression, recipes, _rng)
	skills.levels.clear()
	skills.slots.clear()
	skills.passives.clear()
	battle_relic = &""
	_equipped.clear()
	for id: StringName in [&"ptsmz", &"ptjs", &"ptxzg", &"ptxzf"]:
		var item := inventory.create_item(id, _rng)
		if item == null:
			continue
		var definition := catalog.get_definition(id)
		if definition != null and not definition.slot().is_empty() and not _equipped.has(String(definition.slot())):
			_equipped[String(definition.slot())] = String(item.uid)

func select_character(character: int) -> bool:
	if character < 1 or character > 5:
		return false
	selected_skin = CharacterAbilityRegistry.skin_id(character)
	_replace_starting_equipment(character)
	return true

func _replace_starting_equipment(character: int) -> void:
	var starting_items := {
		1: [&"ptxzg", &"ptxzf"],
		2: [&"ptsmz", &"ptjs"],
		3: [&"ptdp", &"ptcs"],
		4: [&"ptyyc", &"ptcp"],
		5: [&"pttq", &"ptcf"],
	}
	inventory = ItemInventory.new(catalog)
	alchemy = AlchemyService.new(inventory, progression, recipes, _rng)
	skills.levels.clear()
	skills.slots.clear()
	skills.passives.clear()
	battle_relic = &""
	_equipped.clear()
	for id: StringName in starting_items.get(character, []):
		var item := inventory.create_item(id, _rng)
		if item == null:
			continue
		var definition := catalog.get_definition(id)
		if definition != null and not definition.slot().is_empty():
			_equipped[String(definition.slot())] = String(item.uid)

func attach_actor(actor: CombatActor) -> void:
	detach_actor()
	_actor = weakref(actor)
	skills.apply(actor, selected_skin, ability_catalog)
	equipment = EquipmentLoadout.new(
		inventory,
		actor.combatant.stats,
		actor.abilities,
		actor.combatant.passives,
		func(id: StringName): return content.resolve_ability(id),
		func(id: StringName): return content.resolve_passive(id)
	)
	for slot: String in _equipped:
		equipment.equip(StringName(_equipped[slot]))
	if not equipment.changed.is_connected(_on_equipment_changed):
		equipment.changed.connect(_on_equipment_changed)
	_sync_battle_relic()
	apply_progression(actor)

func apply_progression(actor: CombatActor) -> void:
	OriginalCombatCatalog.apply_character(actor, CharacterAbilityRegistry.character_id(selected_skin), progression.level)

func _apply_skills() -> void:
	var actor: CombatActor = _actor.get_ref() if _actor != null else null
	if is_instance_valid(actor):
		skills.apply(actor, selected_skin, ability_catalog)
		_sync_battle_relic()

func detach_actor() -> void:
	_actor = null
	if equipment != null:
		_equipped = equipment.serialize()
		equipment.dispose()
		equipment = null

func serialize() -> Dictionary:
	return {"battle_relic": String(battle_relic), "skills": skills.serialize(), "inventory": inventory.serialize(), "equipment": equipment.serialize() if equipment != null else _equipped.duplicate(), "progression": progression.serialize(), "quests": quests.serialize(), "selected_skin": String(selected_skin), "last_level": String(last_level)}

func restore(data: Dictionary) -> bool:
	if not data.get("inventory") is Dictionary or not data.get("equipment") is Dictionary or not data.get("progression") is Dictionary or not data.get("quests") is Dictionary:
		return false
	if not data.get("battle_relic", "") is String or not data.get("selected_skin", "tang_sanzang") is String:
		return false
	var restored_skin := StringName(data.get("selected_skin", "tang_sanzang"))
	if not CharacterAbilityRegistry.SKIN_TO_CHARACTER.has(restored_skin):
		return false
	var next_skills := SkillProgression.new()
	if not data.get("skills", {}) is Dictionary or not next_skills.restore(data.get("skills", {}), ability_catalog, CharacterAbilityRegistry.character_id(restored_skin)):
		return false
	var next_inventory := ItemInventory.new(catalog)
	var next_progression := PlayerProgression.new()
	var next_quests := QuestJournal.new()
	for definition: Dictionary in quests.entries():
		next_quests.register(definition)
	if not next_inventory.restore(data.inventory) or not next_progression.restore(data.progression) or not next_quests.restore(data.quests):
		return false
	detach_actor()
	skills = next_skills
	skills.changed.connect(_apply_skills)
	inventory = next_inventory
	progression = next_progression
	alchemy = AlchemyService.new(inventory, progression, recipes, _rng)
	quests = next_quests
	var restored_slots: Dictionary = {}
	for slot: Variant in data.equipment:
		if not slot is String or not data.equipment[slot] is String:
			return false
		var uid := StringName(data.equipment[slot])
		var item := inventory.get_item(uid)
		if item == null or restored_slots.has(slot):
			return false
		var definition := catalog.get_definition(item.definition_id)
		if definition == null or definition.slot() != StringName(slot):
			return false
		restored_slots[slot] = String(uid)
	_equipped = restored_slots
	battle_relic = StringName(data.get("battle_relic", ""))
	selected_skin = restored_skin
	last_level = StringName(data.get("last_level", "level_1"))
	return true

func select_battle_relic(uid: StringName) -> bool:
	var item := inventory.get_item(uid)
	if item == null or catalog.get_definition(item.definition_id).slot() != &"relic":
		return false
	battle_relic = uid
	_sync_battle_relic()
	return true

func _on_equipment_changed(slot: StringName) -> void:
	if slot == &"relic":
		_sync_battle_relic()

func _sync_battle_relic() -> void:
	var actor: CombatActor = _actor.get_ref() if _actor != null else null
	if not is_instance_valid(actor):
		return
	var item := inventory.get_item(battle_relic)
	if item == null and equipment != null:
		item = equipment.equipped(&"relic")
		battle_relic = item.uid if item != null else &""
	actor.abilities.remove_source(&"battle_relic")
	var input := actor.get_node_or_null("PlayerInput")
	if input == null or not input.source is ActionInputSource:
		return
	input.source.slots.erase(&"magic_weapon")
	if item != null:
		var ids := catalog.get_definition(item.definition_id).skill_ids()
		if not ids.is_empty():
			var definition := content.resolve_ability(StringName(ids[0]))
			actor.abilities.grant(definition, &"battle_relic", &"magic_weapon", &"magic_weapon")
			input.source.slots[&"magic_weapon"] = definition.id
	actor.abilities.grants_changed.emit()
