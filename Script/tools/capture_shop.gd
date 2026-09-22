extends SceneTree

const OUTPUT := "res://../verification/refactor-ui/shop-strict.png"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(940, 590)
	var profile := PlayerProfile.new()
	profile.start_new()
	var shop := load("res://Scene/Shop/SHOP.tscn").instantiate() as ShopScreen
	shop.profile = profile
	root.add_child(shop)
	for index in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../verification/refactor-ui"))
	root.get_texture().get_image().save_png(OUTPUT)
	shop.queue_free()
	await process_frame
	quit()
