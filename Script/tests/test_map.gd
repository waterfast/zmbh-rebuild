extends SceneTree

var checks := 0
var failures := 0

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
	var store := SaveStore.new("user://map_test_%d.json" % Time.get_ticks_usec())
	var map := MapScreen.create_for_profile(profile, store)
	root.add_child(map)
	await process_frame
	check(map.page == 1 and map.get_node_or_null("level_1") != null, "第一张原选关地图可实例化")
	check(not map.get_node("level_1").disabled and map.get_node("level_2").disabled, "原关卡解锁顺序保留")
	check(map.get_node_or_null("Shop") != null and map.get_node_or_null("Task") != null, "原地图商店和任务按钮节点保留")
	map._activate("Shop")
	await process_frame
	check(map.overlay is ShopScreen and map.overlay.profile == profile, "地图商店按钮注入同一玩家档案")
	map._close_overlay()
	profile.progression.complete_level("level_1")
	check(map.is_level_unlocked(&"level_2"), "通关后下一关路线解锁")
	map.queue_free()
	await process_frame
	profile.last_level = &"level_11"
	var second := MapScreen.create_for_profile(profile, store)
	root.add_child(second)
	await process_frame
	check(second.page == 2 and second.get_node_or_null("Level_11") != null, "切换存档后按关卡进入原第二张地图")
	second.queue_free()
	await process_frame
	print("MAP TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
