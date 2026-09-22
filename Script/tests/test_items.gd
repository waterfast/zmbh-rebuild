extends SceneTree

const Catalog = preload("res://Script/systems/items/item_catalog.gd")
const Inventory = preload("res://Script/systems/items/item_inventory.gd")
const Loadout = preload("res://Script/systems/items/equipment_loadout.gd")
const Economy = preload("res://Script/systems/items/item_economy.gd")
const Progression = preload("res://Script/systems/progression/progression.gd")
const Stats = preload("res://Script/core/stats/stats.gd")
const Definition = preload("res://Script/core/stats/stat_definition.gd")

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var catalog := Catalog.new(2)
	var inventory := Inventory.new(catalog, 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var weapon := inventory.create_item(&"ptxzg", rng)
	check(weapon != null and weapon.rolls.has("power"), "随机属性在创建时生成")
	var first_roll := float(weapon.rolls.power)
	var cached := catalog.get_definition(&"ptxzg")
	check(cached != null and catalog.disk_reads == 1, "定义按需读取并缓存")
	var armor := inventory.create_item(&"ptxzf", rng)
	check(armor != null and armor.rolls.has("SHp"), "防具范围属性生成一次")
	check(weapon.roll_source == &"legacy" and weapon.roll_level == 1, "物品随机值记录创建上下文而非定义级共享")
	check(is_equal_approx(float(weapon.rolls.power), float(first_roll)), "读取定义不会重掷实例")
	var saved := inventory.serialize()
	var restored := Inventory.new(catalog, 4)
	check(restored.restore(saved), "合法存档可恢复")
	check(restored.get_item(weapon.uid) != null and is_equal_approx(restored.get_item(weapon.uid).rolls.power, first_roll), "恢复保留随机结果")
	var stats := Stats.new(Definition.new())
	var loadout := Loadout.new(restored, stats)
	check(loadout.equip(weapon.uid), "武器可装备")
	check(is_equal_approx(stats.value(&"attack"), 20.0 + float(first_roll)), "装备 modifier 应用")
	check(not restored.remove(weapon.uid), "已装备实例不可从背包删除")
	check(loadout.unequip(&"weapon"), "卸下装备")
	check(is_equal_approx(stats.value(&"attack"), 20.0), "卸下撤销 modifier")
	check(restored.remove(weapon.uid), "卸下后可删除")
	var invalid := saved.duplicate(true)
	invalid.items[0].rolls.power = 999999
	check(not restored.restore(invalid), "越界随机值存档被拒绝")
	var relic_definition := catalog.get_definition(&"dshl")
	check(relic_definition != null and relic_definition.skill_ids().size() == 1, "法宝技能通过独立注册表解析")
	var progression := Progression.new()
	progression.gold = 100
	var economy := Economy.new(restored, progression)
	var bought := economy.buy(&"ptxzg", rng)
	check(bought != null and progression.gold == 80, "购买成功后扣除售价")
	check(economy.sell(bought.uid) and progression.gold == 100, "出售成功后增加售价")
	check(not economy.sell(bought.uid) and progression.gold == 100, "重复出售不会重复加钱")
	print("ITEM TESTS: %d failures" % failures)
	quit(1 if failures > 0 else 0)
