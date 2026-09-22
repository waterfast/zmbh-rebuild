extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://verification/" + name + ".png")
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://verification"))
	root.size = Vector2i(940,590)
	var app: GameApp = load("res://app/game_app.tscn").instantiate()
	app.load_saved_profile = false
	app.save_store = SaveStore.new("user://rebuild_verification_only.json")
	app.profile.start_new()
	app.profile.select_character(1)
	root.add_child(app)
	app.encounter.set_physics_process(false)
	for child in app.world.actors.get_children():
		if child != app.player: child.queue_free()
	app.player.get_node("PlayerInput").set_physics_process(false)
	app.player.position = Vector2(1178,400)
	for index in 45: await physics_frame
	await capture("slope-top")
	app.profile.progression.gold = 100000
	var relic := app.profile.inventory.create_item(&"dshl", RandomNumberGenerator.new())
	app.profile.equipment.equip(relic.uid)
	app._show_magic_weapon()
	app.magic_weapon_screen._on_up_level_pressed()
	await capture("relic-upgrade")
	app.magic_weapon_screen._on_szfb_pressed()
	await capture("relic-battle-selection")
	app._close_magic_weapon()
	await process_frame
	app._show_skills()
	await capture("skill-learning")
	app.skill_screen._on_bd_skill_pressed()
	await capture("passive-learning")
	app._close_skills()
	await process_frame
	app.player.attack()
	for index in 3: await physics_frame
	await capture("wukong-normal-effects")
	for index in 30: await physics_frame
	app.profile.skills.learn(app.profile.ability_catalog.resolve(&"lyfb"), 1, app.profile.progression)
	app.player.abilities.restore_mp(app.player.combatant.stats.value(&"max_mp"))
	app.player.use_ability(&"lyfb")
	for index in 12: await physics_frame
	await capture("wukong-fire-storm")
	app.queue_free()
	await process_frame
	quit()
