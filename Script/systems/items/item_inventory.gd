class_name ItemInventory
extends RefCounted

signal changed(uid: StringName)

var catalog: ItemCatalog
var capacity: int
var _items: Dictionary = {}
var _reserved: Dictionary = {}
var _next_id: int = 1

func _init(item_catalog: ItemCatalog, maximum_items: int = 120) -> void:
	catalog = item_catalog
	capacity = maxi(1, maximum_items)

func create_item(id: StringName, rng: RandomNumberGenerator) -> ItemInstance:
	return create_item_with_context(id, ItemRollContext.new(rng, &"legacy"))

func create_item_with_context(id: StringName, context: ItemRollContext) -> ItemInstance:
	if context == null:
		context = ItemRollContext.new()
	if _items.size() >= capacity:
		return null
	var definition := catalog.get_definition(id)
	if definition == null:
		return null
	var instance := ItemInstance.new()
	instance.uid = StringName("item_%d" % _next_id)
	_next_id += 1
	instance.definition_id = id
	instance.roll_source = context.source
	instance.roll_level = context.level
	instance.rolls = definition.roll(context.rng)
	if definition.slot() == &"relic":
		instance.elements = _roll_elements(context.rng)
	_items[instance.uid] = instance
	changed.emit(instance.uid)
	return instance

func get_item(uid: StringName) -> ItemInstance:
	return _items.get(uid)

func item_ids() -> Array:
	return _items.keys()

func remove(uid: StringName) -> bool:
	if _reserved.has(uid) or not _items.has(uid):
		return false
	_items.erase(uid)
	changed.emit(uid)
	return true

func enhance(uid: StringName, level: int) -> bool:
	var instance := get_item(uid)
	if instance == null or level < 0 or level > 1000000 or catalog.get_definition(instance.definition_id).slot().is_empty():
		return false
	instance.enhancement = level
	changed.emit(uid)
	return true

func reserve(uid: StringName, owner: int) -> bool:
	if not _items.has(uid) or _reserved.has(uid):
		return false
	_reserved[uid] = owner
	return true

func release(uid: StringName, owner: int) -> void:
	if _reserved.get(uid) == owner:
		_reserved.erase(uid)

func available_to(uid: StringName, owner: int) -> bool:
	return _items.has(uid) and (not _reserved.has(uid) or _reserved[uid] == owner)

func socket(uid: StringName, gem_uid: StringName) -> bool:
	var instance := get_item(uid)
	var gem := get_item(gem_uid)
	if instance == null or gem == null or uid == gem_uid or _reserved.has(gem_uid) or not gem.gems.is_empty():
		return false
	var definition := catalog.get_definition(instance.definition_id)
	var gem_definition := catalog.get_definition(gem.definition_id)
	if definition.slot() not in [&"weapon", &"armor", &"accessory"] or instance.gems.size() >= 4 or gem_definition.metadata().get("所属", "") != "宝石":
		return false
	instance.gems.append(gem.serialize())
	_items.erase(gem_uid)
	changed.emit(gem_uid)
	changed.emit(uid)
	return true

func unsocket(uid: StringName, index: int) -> bool:
	var instance := get_item(uid)
	if instance == null or index < 0 or index >= instance.gems.size() or _items.size() >= capacity:
		return false
	var gem := ItemInstance.from_data(instance.gems[index])
	instance.gems.remove_at(index)
	_items[gem.uid] = gem
	changed.emit(gem.uid)
	changed.emit(uid)
	return true

func serialize() -> Dictionary:
	var rows: Array = []
	for instance: ItemInstance in _items.values():
		rows.append(instance.serialize())
	return {"schema_version": 1, "next_id": _next_id, "items": rows}

func restore(data: Dictionary) -> bool:
	# 装备先解除引用，再事务性恢复背包，避免现有槽位指向被替换的实例。
	var serialized_next: Variant = data.get("next_id", 1)
	if not (serialized_next is int or serialized_next is float) or not is_finite(float(serialized_next)) or float(serialized_next) < 1 or float(serialized_next) != floorf(float(serialized_next)) or float(serialized_next) >= 9223372036854775806:
		return false
	if not _reserved.is_empty() or data.get("schema_version") != 1 or not data.get("items") is Array or data["items"].size() > capacity:
		return false
	var restored: Dictionary = {}
	var next_id := 1
	var all_ids: Dictionary = {}
	for row: Variant in data["items"]:
		if not _valid_row(row, all_ids, false):
			return false
		var instance := ItemInstance.from_data(row)
		restored[instance.uid] = instance
	for uid: String in all_ids:
		next_id = maxi(next_id, int(uid.trim_prefix("item_")) + 1)
	_items = restored
	_next_id = maxi(next_id, int(serialized_next))
	changed.emit(&"")
	return true

func _valid_row(row: Variant, all_ids: Dictionary, is_gem: bool) -> bool:
	if not row is Dictionary or not row.get("uid") is String or not row.get("definition_id") is String or not row.get("rolls") is Dictionary or not row.get("elements", []) is Array or not row.get("gems", []) is Array:
		return false
	var roll_source: Variant = row.get("roll_source", "unknown")
	var roll_level: Variant = row.get("roll_level", 1)
	if not roll_source is String or roll_source.length() > 64 or not (roll_level is int or roll_level is float) or not is_finite(float(roll_level)) or float(roll_level) != floorf(float(roll_level)) or float(roll_level) < 1 or float(roll_level) > 1000000:
		return false
	var uid := String(row.uid)
	var suffix := uid.trim_prefix("item_")
	if not uid.begins_with("item_") or not suffix.is_valid_int() or int(suffix) < 1 or str(int(suffix)) != suffix or int(suffix) >= 9223372036854775806 or all_ids.has(uid):
		return false
	var level: Variant = row.get("enhancement", 0)
	if not (level is float or level is int) or not is_finite(float(level)) or float(level) != floorf(float(level)) or float(level) < 0 or float(level) > 1000000:
		return false
	var definition := catalog.get_definition(StringName(row.definition_id))
	if definition == null or not definition.valid_rolls(row.rolls):
		return false
	var elements: Array = row.get("elements", [])
	var seen_elements: Dictionary = {}
	if elements.size() > 3 or (definition.slot() != &"relic" and not elements.is_empty()):
		return false
	for element: Variant in elements:
		if not element is String or element not in ["金", "木", "水", "火", "土"] or seen_elements.has(element):
			return false
		seen_elements[element] = true
	var gems: Array = row.get("gems", [])
	if is_gem and (not gems.is_empty() or definition.metadata().get("所属", "") != "宝石"):
		return false
	if gems.size() > 4 or (definition.slot() not in [&"weapon", &"armor", &"accessory"] and not gems.is_empty()):
		return false
	all_ids[uid] = true
	for gem: Variant in gems:
		if not _valid_row(gem, all_ids, true):
			return false
	return true

func _roll_elements(rng: RandomNumberGenerator) -> Array:
	var roll := rng.randi_range(0, 100)
	var count := 3 if roll <= 10 else (2 if roll < 30 else 1)
	var choices: Array = ["金", "木", "水", "火", "土"]
	var result: Array = []
	for index in range(count):
		var choice := rng.randi_range(0, choices.size() - 1)
		result.append(choices[choice])
		choices.remove_at(choice)
	return result
