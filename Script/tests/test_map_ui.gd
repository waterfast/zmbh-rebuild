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
	var store := SaveStore.new("user://map_ui_test.json")
	var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/maps/routes.json"))
	check(routes.size() == 5, "五张原选关地图路由已迁移")
	for page in range(1, 6):
		var map := load("res://Scene/Main_menu/Map_%d.tscn" % page).instantiate() as MapScreen
		map.profile = profile
		map.save_store = store
		root.add_child(map)
		await process_frame
		check(map.page == page, "地图页码保留：%d" % page)
		check(map.get_node_or_null("background") != null or map.get_node_or_null("BackGround") != null or map.get_node_or_null("Tt") != null or map.get_node_or_null("Jjtj") != null or map.get_node_or_null("Byg") != null, "地图原背景节点保留：%d" % page)
		check(map._routes.size() == routes[str(page)].size(), "原地图按钮路由数量保留：%d" % page)
		map.free()
	var map1 := MapScreen.create_for_profile(profile, store)
	check(map1.page == 1 and map1.profile == profile and map1.save_store == store, "MapScreen 支持显式注入档案和存档")
	root.add_child(map1)
	await process_frame
	var first := map1.get_node("level_1") as TextureButton
	check(not first.disabled, "首关默认可进入")
	check((map1.get_node("level_2") as TextureButton).disabled, "后续关卡按通关记录锁定")
	var preview := load("res://Scene/OtherScene/LevelInfo.tscn").instantiate() as LevelPreview
	preview.level_id = &"level_1"
	preview.profile = profile
	root.add_child(preview)
	await process_frame
	check(preview.get_node("ColorRect/TextureRect/Title").text == "花果山", "原关卡确认窗口显示关卡名")
	check(preview.get_node("ColorRect/TextureRect/ScrollContainer2/MonsterList").get_child_count() == 3, "原确认窗口保留敌方头像列表")
	check(preview.get_node("ColorRect/TextureRect/ScrollContainer/FallList").get_child_count() == 10, "原确认窗口保留掉落预览列表")
	var started: Array[StringName] = []
	preview.challenge_requested.connect(func(id: StringName): started.append(id))
	preview.get_node("ColorRect/TextureRect/Challenge").pressed.emit()
	check(started == [&"level_1"], "挑战按钮使用新关卡 ID 信号")
	var challenge := preview.get_node("ColorRect/TextureRect/Challenge") as TextureButton
	var speed := preview.get_node("ColorRect/TextureRect/Speed") as TextureButton
	var fall_scroll := preview.get_node("ColorRect/TextureRect/ScrollContainer") as ScrollContainer
	check(challenge.get_global_rect().has_point(challenge.get_global_rect().get_center()), "挑战按钮命中区域有效")
	check(speed.get_global_rect().has_point(speed.get_global_rect().get_center()), "移速按钮命中区域有效")
	check(fall_scroll.get_global_rect().has_point(fall_scroll.get_global_rect().get_center()), "掉落滚动区域命中区域有效")
	var speed_event := InputEventMouseButton.new()
	speed_event.button_index = MOUSE_BUTTON_LEFT
	speed_event.pressed = true
	speed_event.position = speed.get_global_rect().get_center()
	Input.parse_input_event(speed_event)
	await process_frame
	check(preview.get_node("ColorRect/TextureRect/Speed/speedtext").text == "×2", "真实点击移速按钮切换倍率")
	preview.free()
	map1.free()
	print("MAP UI TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
