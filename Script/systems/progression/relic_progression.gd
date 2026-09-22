class_name RelicProgression
extends RefCounted
## 法宝升级和洗炼交易；UI 不直接写属性或绕过材料校验。
var inventory: ItemInventory
var wallet: PlayerProgression
var rng := RandomNumberGenerator.new()

func _init(items: ItemInventory, progression: PlayerProgression) -> void:
	inventory = items
	wallet = progression
	rng.randomize()

func cost(item: ItemInstance) -> int:
	return 1000 * (item.enhancement + 1) * (item.enhancement + 1) if item != null and item.enhancement < 10 else 0

func upgrade(uid: StringName) -> String:
	var item := _relic(uid)
	if item == null:
		return "请先装备法宝"
	if item.enhancement >= 10:
		return "法宝已经满级"
	if not wallet.spend(cost(item)):
		return "灵魂不足"
	inventory.enhance(uid, item.enhancement + 1)
	return ""

func refine(uid: StringName, kind: StringName) -> String:
	var item := _relic(uid)
	if item == null:
		return "请先装备法宝"
	if kind not in [&"elements", &"advanced", &"growth"]:
		return "无效洗炼类型"
	var material := &"czlxls" if kind == &"growth" else &"wxxls"
	var count := maxi(1, item.elements.size() * 5) if kind == &"advanced" else 1
	var ingredients: Array[StringName] = []
	for id: StringName in inventory.item_ids():
		if inventory.get_item(id).definition_id == material and inventory.available_to(id, 0):
			ingredients.append(id)
	if ingredients.size() < count:
		return "洗炼石数量不足，需%d颗" % count
	for index in count:
		inventory.remove(ingredients[index])
	if kind == &"growth":
		var definition := inventory.catalog.get_definition(item.definition_id)
		item.rolls["成长率"] = definition.roll(rng).get("成长率", 1.0)
	else:
		var roll := rng.randi_range(0, 100)
		var element_count := mini(3, item.elements.size() + 1) if kind == &"advanced" else (3 if roll <= 4 else (2 if roll < 10 else 1))
		var choices := ["金", "木", "水", "火", "土"]
		item.elements.clear()
		for index in element_count:
			var pick := rng.randi_range(0, choices.size() - 1)
			item.elements.append(choices.pop_at(pick))
	inventory.changed.emit(uid)
	return ""

func _relic(uid: StringName) -> ItemInstance:
	var item := inventory.get_item(uid)
	return item if item != null and inventory.catalog.get_definition(item.definition_id).slot() == &"relic" else null
