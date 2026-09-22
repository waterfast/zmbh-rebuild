class_name ItemEconomy
extends RefCounted
## 商店和强化只通过背包公开接口操作；货币变更发生在操作成功边界。

var _inventory: ItemInventory
var _progression: PlayerProgression

func _init(inventory: ItemInventory, progression: PlayerProgression) -> void:
	_inventory = inventory
	_progression = progression

func buy(id: StringName, rng: RandomNumberGenerator, price_override: int = -1) -> ItemInstance:
	var definition := _inventory.catalog.get_definition(id)
	if definition == null:
		return null
	var price := price_override if price_override >= 0 else int(definition.metadata().get("售价", 0))
	if price < 0:
		return null
	var instance := _inventory.create_item_with_context(id, ItemRollContext.new(rng, &"shop"))
	if instance == null:
		return null
	if not _progression.spend(price):
		_inventory.remove(instance.uid)
		return null
	return instance

func sell(uid: StringName, price_override: int = -1) -> bool:
	var instance := _inventory.get_item(uid)
	if instance == null:
		return false
	var definition := _inventory.catalog.get_definition(instance.definition_id)
	if definition == null:
		return false
	var price := price_override if price_override >= 0 else int(definition.metadata().get("售价", 0))
	if price < 0 or not _inventory.remove(uid):
		return false
	_progression.reward(0, price)
	return true

func buy_many(id: StringName, quantity: int, rng: RandomNumberGenerator, unit_price: int) -> bool:
	if quantity <= 0 or unit_price < 0 or quantity > _inventory.capacity - _inventory.item_ids().size():
		return false
	if _inventory.catalog.get_definition(id) == null or _progression.gold < quantity * unit_price:
		return false
	var created: Array[StringName] = []
	for index in range(quantity):
		var instance := _inventory.create_item_with_context(id, ItemRollContext.new(rng, &"shop"))
		if instance == null:
			for uid: StringName in created:
				_inventory.remove(uid)
			return false
		created.append(instance.uid)
	if not _progression.spend(quantity * unit_price):
		for uid: StringName in created:
			_inventory.remove(uid)
		return false
	return true

func enhance(uid: StringName, level: int, price_per_level: int = 10) -> bool:
	var instance := _inventory.get_item(uid)
	if instance == null or level < instance.enhancement or price_per_level < 0:
		return false
	var cost := (level - instance.enhancement) * price_per_level
	if not _progression.spend(cost):
		return false
	if not _inventory.enhance(uid, level):
		_progression.reward(0, cost)
		return false
	return true
