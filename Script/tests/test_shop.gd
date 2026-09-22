extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var profile := PlayerProfile.new()
	profile.start_new()
	var catalog := ShopCatalog.new(profile.catalog)
	check(catalog.offers(2, 1).size() == 20, "唐僧保留原20项常规商品")
	check(catalog.find_offer(2, 1, &"qhs_1").price == 4000, "商品使用原商店价格而非物品出售价格")
	check(catalog.find_offer(2, 1, &"jcz").is_empty() and catalog.find_offer(2, 50, &"jcz").price == 200000, "50级角色时装按原条件解锁")
	check(catalog.find_offer(2, 1, &"wkbsz").is_empty(), "角色专属商品不串角色")
	check(catalog.offers(2, 1, "翅膀").size() == 1, "原商品分类")
	var item_name: String = profile.catalog.get_definition(&"qhs_1").metadata()["名字"]
	check(catalog.offers(2, 1, "全部", item_name).size() == 1, "按原商品名称搜索")
	var economy := ItemEconomy.new(profile.inventory, profile.progression)
	var random := RandomNumberGenerator.new()
	var initial_count := profile.inventory.item_ids().size()
	profile.progression.gold = 9000
	check(economy.buy_many(&"qhs_1", 2, random, 4000), "一次购买原指定数量")
	check(profile.progression.gold == 1000 and profile.inventory.item_ids().size() == initial_count + 2, "成功后精确扣钱并生成物品")
	check(not economy.buy_many(&"qhs_1", 1, random, 4000) and profile.inventory.item_ids().size() == initial_count + 2, "钱不足不产生物品")
	profile.inventory.capacity = profile.inventory.item_ids().size()
	check(not economy.buy_many(&"xczg", 1, random, 0) and profile.progression.gold == 1000, "背包满时免费商品也不溢出")
	profile.inventory.capacity = 120
	var shop := load("res://Scene/Shop/SHOP.tscn").instantiate() as ShopScreen
	shop.profile = profile
	root.add_child(shop)
	check(shop.get_node("BG/BG2/ShopTypeChange/Total") is TextureButton, "旧分类按钮节点保留")
	check(shop._rows.size() == 9 and shop.maximum_page == 3, "原九宫商品布局与分页")
	check(shop._rows[0].position == Vector2(-220, -120) and shop._rows[8].position == Vector2(220, 80), "商品格位置与旧脚本一致")
	shop._on_next_pressed()
	shop._on_next_pressed()
	check(shop.current_page == 3 and shop._rows.size() == 2, "末页保留两项商品")
	shop._on_cb_pressed()
	check(shop.current_page == 1 and shop._rows.size() == 1, "分类切换重置分页")
	profile.progression.gold = 9000
	shop._request_purchase(&"qhs_1", 1)
	check(profile.progression.gold == 9000, "购买先显示原确认窗口，不提前扣款")
	shop._confirmation.get_node("TextureRect/bg/qd").pressed.emit()
	check(profile.progression.gold == 5000, "原确认按钮触发交易")
	shop._request_purchase(&"wkbsz", 1)
	check(profile.progression.gold == 5000, "不能通过界面回调购买角色外商品")
	shop.queue_free()
	await process_frame
	await process_frame
	print("SHOP TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
