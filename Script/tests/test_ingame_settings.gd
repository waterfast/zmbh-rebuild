extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var app: GameApp = load("res://app/game_app.tscn").instantiate() as GameApp
	app.load_saved_profile = false
	app.profile.start_new()
	root.add_child(app)
	for index in range(4):
		await process_frame
	app._show_settings()
	await process_frame
	check(app.settings_screen is InGameSettingsScreen, "局内打开原版暂停页")
	check(app.settings_screen.get_node("bg/box/continue_game2") != null, "原版暂停页保留返回地图按钮")
	check(app.settings_screen.get_node("bg/box/continue_game4") != null, "原版暂停页保留返回主菜单按钮")
	app.settings_screen._on_continue_game_2_pressed()
	await process_frame
	check(root.get_tree().current_scene is MapScreen, "退出关卡返回地图")
	print("IN-GAME SETTINGS TESTS: %d failures" % failures)
	quit(1 if failures > 0 else 0)
