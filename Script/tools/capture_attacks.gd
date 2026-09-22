extends SceneTree

const OUTPUT_DIRECTORY := "res://../verification/refactor-ui"

func _initialize() -> void:
	_run.call_deferred()

func _capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUTPUT_DIRECTORY.path_join(filename))
	if result != OK:
		push_error("攻击截图保存失败：%s" % filename)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	root.size = Vector2i(940, 590)
	var app: GameApp = load("res://app/game_app.tscn").instantiate()
	app.load_saved_profile = false
	app.profile.start_new()
	root.add_child(app)
	app.encounter.set_physics_process(false)
	for actor in app.world.actors.get_children():
		if actor != app.player:
			actor.queue_free()
	app.player.get_node("PlayerInput").set_physics_process(false)
	for frame_index in range(60):
		await physics_frame
	app.player.facing = 1.0
	app.player.attack()
	for frame_index in range(23):
		await physics_frame
	await _capture("tang-sanzang-normal-attack.png")
	for frame_index in range(60):
		await physics_frame
	app.player.use_ability(&"ice_dragon_wave")
	for frame_index in range(52):
		await physics_frame
	await _capture("tang-sanzang-ice-dragon-wave.png")
	app.queue_free()
	await process_frame
	print("ATTACK CAPTURE: saved two original spell views")
	quit()
