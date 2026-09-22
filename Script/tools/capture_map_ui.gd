extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(940, 590)
	var profile := PlayerProfile.new()
	profile.start_new()
	var map := MapScreen.create_for_profile(profile, SaveStore.new("user://map_capture.json"))
	root.add_child(map)
	await process_frame
	await RenderingServer.frame_post_draw
	var map_result := root.get_texture().get_image().save_png("res://../verification/refactor-ui/map-1.png")
	var preview := load("res://Scene/OtherScene/LevelInfo.tscn").instantiate() as LevelPreview
	preview.level_id = &"level_1"
	preview.profile = profile
	root.add_child(preview)
	await process_frame
	await RenderingServer.frame_post_draw
	var preview_result := root.get_texture().get_image().save_png("res://../verification/refactor-ui/map-level-info.png")
	print("MAP CAPTURE: map=%s preview=%s" % [map_result, preview_result])
	quit(0 if map_result == OK and preview_result == OK else 1)
