extends SceneTree

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var app: GameApp = load("res://app/game_app.tscn").instantiate() as GameApp
	app.load_saved_profile = false
	app.save_store = SaveStore.new("user://test_app_only.json")
	app.profile.start_new()
	root.add_child(app)
	for index in range(4):
		await process_frame
	check(app.world != null, "应用创建 WorldSession")
	check(app.world.definition != null and app.world.definition.id == &"level_1", "应用加载第一关定义")
	check(app.player != null and app.player.combatant != null, "应用创建新 Actor")
	check(app.encounter != null and not app.encounter.finished, "应用创建关卡波次")
	check(app.hud != null and app.hud.get_node_or_null("RoleInformation") != null, "应用实例化 Scene/UI/GameHUD")
	check(app.profile.inventory.item_ids().size() >= 0, "应用创建玩家档案")
	check(app.hud.get_parent() is CanvasLayer, "HUD 固定在屏幕显示层")
	app._show_inventory()
	await process_frame
	check(paused and not app.world.can_process(), "背包打开后暂停世界")
	check(app.inventory_screen.can_process(), "暂停中背包仍处理按钮")
	check(app.inventory_screen.get_parent() == app.ui_layer, "背包不随镜头移动")
	app.inventory_screen.closed.emit()
	check(not paused and app.inventory_screen == null, "关闭背包恢复世界")
	app._toggle_pause()
	check(paused and app.can_process(), "手动暂停仍可处理恢复输入")
	app._show_quests()
	app.quest_screen.closed.emit()
	check(paused, "关闭面板不取消先前的手动暂停")
	app._toggle_pause()
	check(not paused, "再次暂停操作恢复运行")
	app._show_inventory()
	app._toggle_pause()
	check(app.inventory_screen == null and not paused, "Esc 关闭面板并恢复运行")
	# 死亡：播完死亡表现后弹出战败界面并暂停世界
	app.player.combatant.health.damage(app.player.combatant.health.maximum * 10.0)
	for index in range(130):
		await physics_frame
	await process_frame
	check(app.defeat_screen != null and app.defeat_screen.get_parent() == app.ui_layer, "角色死亡后弹出战败界面")
	check(paused and not app.world.can_process(), "战败界面暂停世界")
	app.defeat_screen.retry_requested.emit()
	await process_frame
	check(app.defeat_screen == null and not paused, "重新挑战关闭战败界面并重开关卡")
	# 通关：结算界面显示用时/血量/星级
	app.encounter.finished = true
	app._on_level_completed()
	await process_frame
	check(app.victory_screen != null and app.victory_screen.report != null, "通关后弹出结算界面")
	check(app.victory_screen.report.star_rating >= 1 and app.victory_screen.report.star_rating <= 5, "结算星级在 1~5 星之间")
	check(app.victory_screen.report.hp_percent >= 0.0, "结算保留剩余血量百分比")
	app.victory_screen.get_node("MoreInformaition").pressed.emit()
	check(app.victory_screen.get_node_or_null("AfterLevelEnd") != null, "通关更多信息打开原版统计弹窗")
	app.victory_screen.map_requested.emit()
	await process_frame
	if is_instance_valid(app):
		app.queue_free()
	for index in 4:
		await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_app_only.json"))
	print("APP TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
