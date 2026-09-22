extends SceneTree

var checks: int = 0
var failures: int = 0
var close_requests: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	root.size = Vector2i(940, 590)
	GameInputBindings.install()
	var profile := PlayerProfile.new()
	profile.start_new()
	profile.progression.gold = 500
	var player: CombatActor = load("res://actors/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player.get_node("PlayerInput").set_physics_process(false)
	profile.attach_actor(player)
	var inventory: InventoryScreen = load("res://Scene/UI/Inventory.tscn").instantiate()
	inventory.profile = profile
	inventory.actor = player
	inventory.closed.connect(_on_closed)
	root.add_child(inventory)
	for frame in range(3):
		await process_frame
	check(inventory.position == Vector2(481, 297), "Retains original backpack root and origin")
	check(inventory.get_node("background").texture.resource_path.ends_with("207.png"), "Retains original background scene node")
	check(inventory._grid.columns == 5 and inventory._grid.get_child_count() == 35, "Retains five columns and 35 persistent scene cells")
	check(inventory._grid.get_theme_constant("h_separation") == 11, "Restores original grid separation exactly")
	check(inventory.get_node("background/RoleBody") is Sprite2D and inventory.get_node("background/RoleEquipment") is Sprite2D, "Uses original character sprite nodes")
	check(inventory.get_node("background/Player").current_animation == "wait2", "Uses original preview AnimationPlayer")
	check(inventory.get_node("background/infomation/leve_background/Level_Show/Number_1").texture.resource_path.ends_with("Level_1.png"), "Uses original level digit texture")
	check(inventory.get_node_or_null("ItemDetails") == null, "Does not add custom persistent detail panel")
	check(inventory._cells[0].icon.resource_path.ends_with("ptxzg.png"), "Grid excludes equipped items and loads original icons")
	var node_count := get_node_count()
	for repeat in range(5):
		inventory.refresh()
	check(get_node_count() == node_count, "Refreshing updates cells without rebuilding nodes")
	await _capture("inventory-strict.png")
	var weapon := profile.equipment.equipped(&"weapon")
	inventory._equipment_slots[&"weapon"].pressed.emit()
	check(profile.equipment.equipped(&"weapon") == null, "Original equipment slot click unequips item")
	inventory._select(weapon.uid)
	check(inventory._actions.get_node("VBoxContainer/equ").icon.resource_path.ends_with("5.png"), "Original equip popup icon is retained")
	inventory._actions.get_node("VBoxContainer/equ").pressed.emit()
	check(profile.equipment.equipped(&"weapon") == weapon, "Original popup equip button equips item")
	var attack_before := player.combatant.stats.value(&"attack")
	check(inventory._enhance() and weapon.enhancement == 1 and profile.progression.gold == 475, "Existing strengthen service preserves level and cost")
	check(player.combatant.stats.value(&"attack") > attack_before, "Strengthening refreshes equipped actor modifiers")
	inventory._show_details(weapon.uid)
	inventory._details.follow_pointer = false
	inventory._details.position = Vector2(40, -80)
	check(inventory._details.get_node_or_null("pro_wk/information/inf/VBoxContainer3/eq_power") != null, "Original equipment detail hierarchy is retained")
	await _capture("inventory-details-strict.png")
	inventory._hide_details()
	var definition_preview := load("res://Scene/UI/InventoryDetails.tscn").instantiate() as InventoryItemDetails
	definition_preview.item_definition = profile.catalog.get_definition(&"ptsmz")
	definition_preview.follow_pointer = false
	root.add_child(definition_preview)
	var range_label := definition_preview.get_node("pro_wk/information/inf/VBoxContainer3/eq_power") as Label
	check(range_label.text == "攻击：6.0~10.0" or range_label.text == "攻击：6~10", "Definition preview displays random range without creating an instance")
	definition_preview.refresh()
	check(profile.inventory.item_ids().size() == 4, "Repeated definition previews never roll or insert items")
	definition_preview.queue_free()
	var random := RandomNumberGenerator.new()
	random.seed = 1
	for index in range(38):
		profile.inventory.create_item(&"ptxzg", random)
	inventory.refresh()
	inventory._next_page.pressed.emit()
	check(inventory._page == 1 and inventory._page_text.text == "2/2", "Original next-page control shows second page")
	check(inventory._cells[0].icon.resource_path.ends_with("ptxzg.png"), "Second page is bound to its own item data")
	inventory._last_page.pressed.emit()
	check(inventory._page == 0, "Original previous-page control returns to first page")
	inventory._select(inventory._ids[0])
	inventory._actions.position = Vector2(-70, -90)
	await _capture("inventory-actions-strict.png")
	paused = true
	inventory.get_node("background/close").pressed.emit()
	check(close_requests == 1 and inventory.can_process(), "Original close button remains active while gameplay is paused")
	paused = false
	inventory.queue_free()
	await process_frame
	profile.detach_actor()
	player.queue_free()
	await process_frame
	print("INVENTORY UI TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _capture(filename: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var directory := "res://../verification/refactor-ui"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	root.get_texture().get_image().save_png(directory.path_join(filename))

func _on_closed() -> void:
	close_requests += 1
