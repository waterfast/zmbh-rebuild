extends SceneTree
## 非 headless 执行，以独立新档渲染界面；不读取或写入玩家存档。

const OUTPUT_DIRECTORY := "res://../verification/refactor-ui"

func _initialize() -> void:
	_run.call_deferred()

func _capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUTPUT_DIRECTORY.path_join(filename))
	if result != OK:
		push_error("截图保存失败：%s" % filename)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	root.size = Vector2i(940, 590)
	var menu: Node2D = load("res://Scene/UI/MainMenu.tscn").instantiate()
	menu.archives = ArchiveStore.new("user://ui_capture_%d.json" % Time.get_ticks_usec())
	root.add_child(menu)
	await _capture("main-menu.png")
	menu._on_begin_game_pressed()
	await _capture("archives.png")
	menu._archive_screen.get_node("background/cd_number").text = "1"
	menu._archive_screen._on_delete_pressed()
	await _capture("archive-delete-confirmation.png")
	menu.queue_free()
	await process_frame
	var app: GameApp = load("res://app/game_app.tscn").instantiate()
	app.load_saved_profile = false
	app.profile.start_new()
	root.add_child(app)
	for frame in range(60):
		await physics_frame
	await _capture("level-1.png")
	app._show_inventory()
	await _capture("inventory.png")
	app.queue_free()
	await process_frame
	print("UI CAPTURE: saved five views to %s" % ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	quit()
