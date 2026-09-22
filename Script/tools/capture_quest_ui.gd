extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(940, 590)
	var world := WorldSession.new()
	root.add_child(world)
	world.load_level(&"level_1")
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var screen := load("res://Scene/UI/QuestJournal.tscn").instantiate() as QuestScreen
	screen.profile = PlayerProfile.new()
	layer.add_child(screen)
	paused = true
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://../verification/refactor-ui/quest-journal.png"
	var result := root.get_texture().get_image().save_png(path)
	check_result(result, path)
	layer.queue_free()
	world.queue_free()
	paused = false
	await process_frame
	quit(0 if result == OK else 1)

func check_result(result: Error, path: String) -> void:
	if result != OK:
		push_error("任务界面截图保存失败")
	else:
		print("QUEST CAPTURE: ", ProjectSettings.globalize_path(path))
