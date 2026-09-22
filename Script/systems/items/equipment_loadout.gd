class_name EquipmentLoadout
extends RefCounted

signal changed(slot: StringName)

var _inventory: ItemInventory
var _stats: ActorStats
var _abilities: AbilityController
var _passives: RefCounted
var _ability_resolver: Callable
var _passive_resolver: Callable
var _slots: Dictionary = {}

func _init(inventory: ItemInventory, stats: ActorStats, abilities: AbilityController = null, passives: RefCounted = null, ability_resolver: Callable = Callable(), passive_resolver: Callable = Callable()) -> void:
	_inventory = inventory
	_stats = stats
	_abilities = abilities
	_passives = passives
	_ability_resolver = ability_resolver
	_passive_resolver = passive_resolver
	_inventory.changed.connect(_on_inventory_changed)

func equipped(slot: StringName) -> ItemInstance:
	return _inventory.get_item(_slots.get(slot, &""))

func equip(uid: StringName) -> bool:
	var instance := _inventory.get_item(uid)
	if instance == null or not _inventory.available_to(uid, get_instance_id()):
		return false
	var definition := _inventory.catalog.get_definition(instance.definition_id)
	if definition == null or definition.slot().is_empty() or not _can_grant(definition):
		return false
	var slot := definition.slot()
	if _slots.get(slot) == uid:
		return true
	if not _inventory.reserve(uid, get_instance_id()):
		return false
	unequip(slot)
	_slots[slot] = uid
	_apply(instance, definition)
	changed.emit(slot)
	return true

func unequip(slot: StringName) -> bool:
	if not _slots.has(slot):
		return false
	var uid: StringName = _slots[slot]
	_revoke(uid)
	_inventory.release(uid, get_instance_id())
	_slots.erase(slot)
	changed.emit(slot)
	return true

func clear() -> void:
	for slot: StringName in _slots.keys():
		unequip(slot)

func serialize() -> Dictionary:
	var result: Dictionary = {}
	for slot: StringName in _slots:
		result[String(slot)] = String(_slots[slot])
	return result

func restore(data: Dictionary) -> bool:
	var seen: Dictionary = {}
	for slot: Variant in data:
		if not (slot is String or slot is StringName) or not (data[slot] is String or data[slot] is StringName):
			return false
		var uid := StringName(data[slot])
		var instance := _inventory.get_item(uid)
		if instance == null or seen.has(uid) or not _inventory.available_to(uid, get_instance_id()):
			return false
		var definition := _inventory.catalog.get_definition(instance.definition_id)
		if definition == null or definition.slot() != StringName(slot) or definition.slot().is_empty() or not _can_grant(definition):
			return false
		seen[uid] = true
	clear()
	for uid: Variant in data.values():
		equip(StringName(uid))
	return true

func _can_grant(definition: ItemDefinition) -> bool:
	for id: String in definition.skill_ids():
		if _abilities == null or not _ability_resolver.is_valid() or _ability_resolver.call(StringName(id)) == null:
			return false
	for id: String in definition.passive_ids():
		if _passives == null or not _passive_resolver.is_valid() or _passive_resolver.call(StringName(id)) == null:
			return false
	return true

func _source(uid: StringName) -> StringName:
	return StringName("equipment:%d:%s" % [get_instance_id(), uid])

func _apply(instance: ItemInstance, definition: ItemDefinition) -> void:
	var source := _source(instance.uid)
	var modifiers := definition.stats(instance)
	for gem_data: Dictionary in instance.gems:
		var gem := ItemInstance.from_data(gem_data)
		var gem_definition := _inventory.catalog.get_definition(gem.definition_id)
		if gem_definition == null:
			continue
		var gem_stats := gem_definition.stats(gem)
		for stat: StringName in gem_stats:
			modifiers[stat] = float(modifiers.get(stat, 0.0)) + float(gem_stats[stat])
	for stat: StringName in modifiers:
		_stats.set_modifier(source, stat, float(modifiers[stat]))
	var category := &"magic_weapon" if definition.slot() == &"relic" else &"equipment"
	for id: String in definition.skill_ids():
		_abilities.grant(_ability_resolver.call(StringName(id)), source, category, category)
	for id: String in definition.passive_ids():
		_passives.call("grant", _passive_resolver.call(StringName(id)), source)

func _revoke(uid: StringName) -> void:
	var source := _source(uid)
	_stats.remove_source(source)
	if _abilities != null:
		_abilities.remove_source(source)
	if _passives != null:
		_passives.call("remove_source", source)

func _on_inventory_changed(uid: StringName) -> void:
	for slot: StringName in _slots:
		if _slots[slot] != uid:
			continue
		var instance := _inventory.get_item(uid)
		if instance == null:
			unequip(slot)
			continue
		var definition := _inventory.catalog.get_definition(instance.definition_id)
		if definition == null:
			unequip(slot)
			continue
		_revoke(uid)
		_apply(instance, definition)
		changed.emit(slot)

func dispose() -> void:
	clear()
	if _inventory.changed.is_connected(_on_inventory_changed):
		_inventory.changed.disconnect(_on_inventory_changed)
