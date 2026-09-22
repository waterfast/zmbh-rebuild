class_name ContentRegistry
extends RefCounted
## 内容组合根。目录、运行时注册内容和来源元数据集中在一次会话中管理，避免 Autoload 巨型全局表。

var items: ItemCatalog
var abilities: AbilityCatalog
var _registered_abilities: Dictionary = {}
var _registered_passives: Dictionary = {}
var _registered_items: Dictionary = {}

func _init(item_capacity: int = 32, ability_index: String = "res://content/abilities/index.json") -> void:
	items = ItemCatalog.new(item_capacity)
	abilities = AbilityCatalog.new(ability_index)
	_register_relic_abilities()

func register_ability(definition: AbilityDefinition, category: StringName = &"", source_kind: StringName = &"") -> bool:
	if definition == null or definition.id.is_empty():
		return false
	if not category.is_empty():
		definition.category = category
	if not source_kind.is_empty():
		definition.source_kind = source_kind
	_registered_abilities[definition.id] = definition
	return true

func register_ability_definition(definition: AbilityDefinition, category: StringName = &"", source_kind: StringName = &"") -> AbilityDefinition:
	return definition if register_ability(definition, category, source_kind) else null

func resolve_ability(id: StringName, category: StringName = &"") -> AbilityDefinition:
	var definition: AbilityDefinition = _registered_abilities.get(id)
	if definition == null:
		definition = abilities.runtime_resolve(id)
	if definition == null:
		return null
	if category.is_empty() or definition.category == category:
		return definition
	return null

func register_passive(definition: PassiveDefinition, category: StringName = &"", source_kind: StringName = &"") -> bool:
	if definition == null or definition.id.is_empty():
		return false
	if not category.is_empty():
		definition.category = category
	if not source_kind.is_empty():
		definition.source_kind = source_kind
	_registered_passives[definition.id] = definition
	return true

func resolve_passive(id: StringName, category: StringName = &"") -> PassiveDefinition:
	var definition: PassiveDefinition = _registered_passives.get(id)
	if definition == null:
		definition = _default_passive(id)
	if definition == null or (not category.is_empty() and definition.category != category):
		return null
	return definition

func register_item(definition: ItemDefinition) -> bool:
	if definition == null or definition.id.is_empty():
		return false
	_registered_items[definition.id] = definition
	items.register_definition(definition)
	return true

func register_item_data(data: Dictionary) -> ItemDefinition:
	var definition := ItemDefinition.new(data)
	return definition if register_item(definition) else null

func resolve_item(id: StringName) -> ItemDefinition:
	var definition: ItemDefinition = _registered_items.get(id)
	return definition if definition != null else items.get_definition(id)

func _register_relic_abilities() -> void:
	for relic_id: StringName in RelicAbilityRegistry.item_ids():
		register_ability(RelicAbilityRegistry.definition_for(relic_id), &"magic_weapon", &"magic_weapon")

func _default_passive(id: StringName) -> PassiveDefinition:
	var definition := PassiveDefinition.new()
	definition.id = id
	definition.category = &"equipment"
	definition.source_kind = &"equipment"
	definition.lifesteal = 0.05
	definition.cooldown = 1.0
	return definition
