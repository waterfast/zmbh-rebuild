class_name GameApp
extends Node2D
## 应用层负责装配，业务模块不依赖彼此的场景树路径。

const PLAYER_SCENE := preload("res://actors/player.tscn")
const HUD_SCENE := preload("res://Scene/UI/GameHUD.tscn")
const INVENTORY_SCENE := preload("res://Scene/UI/Inventory.tscn")
const QUEST_SCENE := preload("res://Scene/UI/QuestJournal.tscn")
const SETTINGS_SCENE := preload("res://Scene/UI/InGameSettings.tscn")
const SKILL_SCENE := preload("res://Scene/UI/Skill/LearnSkill.tscn")
const MAGIC_WEAPON_SCENE := preload("res://Scene/UI/MagicWeaponUpgrade.tscn")
const DEFEAT_SCENE := preload("res://Scene/Level/DefeatScreen.tscn")
const VICTORY_SCENE := preload("res://Scene/Level/VictoryScreen.tscn")
const PROFILE_PATH := "user://zaomeng_profile.json"
var profile := PlayerProfile.new()
var load_saved_profile: bool = true
var save_store := SaveStore.new(PROFILE_PATH)
var world: WorldSession
var encounter: StageEncounter
var player: CombatActor
var hud: GameHUD
var inventory_screen: InventoryScreen
var quest_screen: QuestScreen
var settings_screen: InGameSettingsScreen
var skill_screen: SkillLearningScreen
var magic_weapon_screen: MagicWeaponUpgrade
var defeat_screen: DefeatScreen
var victory_screen: VictoryScreen
var settings_store := SettingsStore.new()
var ui_layer: CanvasLayer
var _manual_pause: bool = false
var _drop_rng := RandomNumberGenerator.new()
var _level_began_at: String = ""
var _level_started_msec: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameInputBindings.install()
	_drop_rng.seed = 0xBAA08
	if load_saved_profile:
		if save_store.exists() and not profile.restore(save_store.load_data()):
			profile.start_new()
		elif not save_store.exists():
			profile.start_new()
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)
	_setup_world()
	_load_level(profile.last_level)

func _setup_world() -> void:
	world = WorldSession.new()
	world.name = "WorldSession"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)

func _load_level(id: StringName) -> void:
	if is_instance_valid(encounter):
		encounter.queue_free()
		encounter = null
	profile.detach_actor()
	if not world.load_level(id):
		push_error("无法加载关卡：%s" % id)
		return
	player = null
	player = PLAYER_SCENE.instantiate()
	player.debug_draw = false
	world.add_actor(player, world.definition.spawn_position)
	var view := player.get_node_or_null("ActorView") as ActorView
	if view != null:
		view.set_skin(profile.selected_skin)
	profile.attach_actor(player)
	player.combatant.health.heal(player.combatant.health.maximum)
	player.abilities.restore_mp(player.abilities.maximum_mp)
	_level_began_at = Time.get_datetime_string_from_system(false, true)
	_level_started_msec = Time.get_ticks_msec()
	encounter = StageEncounter.new()
	world.add_child(encounter)
	encounter.setup(world, player)
	encounter.enemy_defeated.connect(_on_enemy_defeated)
	encounter.stage_cleared.connect(_on_stage_cleared)
	encounter.completed.connect(_on_level_completed)
	player.combatant.health.died.connect(_on_player_died, CONNECT_ONE_SHOT)
	_create_camera()
	_create_hud()

func _create_camera() -> void:
	var camera := Camera2D.new()
	camera.position = Vector2(0, -40)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = int(world.definition.camera_bounds.position.x)
	camera.limit_top = int(world.definition.camera_bounds.position.y)
	camera.limit_right = int(world.definition.camera_bounds.end.x)
	camera.limit_bottom = int(world.definition.camera_bounds.end.y)
	player.add_child(camera)

func _create_hud() -> void:
	if is_instance_valid(hud):
		hud.queue_free()
	hud = HUD_SCENE.instantiate()
	hud.name = "GameHUD"
	ui_layer.add_child(hud)
	hud.bind(player, profile.progression, world.definition.display_name)
	hud.inventory_requested.connect(_show_inventory)
	hud.quests_requested.connect(_show_quests)
	hud.pause_requested.connect(_toggle_pause)
	hud.settings_requested.connect(_show_settings)
	hud.skill_requested.connect(_show_skills)
	hud.magic_weapon_requested.connect(_show_magic_weapon)
	hud.pet_requested.connect(_show_pet)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("inventory"):
		if is_instance_valid(inventory_screen):
			_close_inventory()
		else:
			_show_inventory()
	if Input.is_action_just_pressed("quests"):
		if is_instance_valid(quest_screen):
			_close_quests()
		else:
			_show_quests()
	if Input.is_action_just_pressed("pause"):
		_toggle_pause()
	if not get_tree().paused and Input.is_action_just_pressed("interact") and encounter != null and encounter.finished and not world.definition.next_level_id.is_empty():
		_load_level(world.definition.next_level_id)
	if Input.is_action_just_pressed("save"):
		_save()

func _show_inventory() -> void:
	if _any_overlay_open():
		return
	inventory_screen = INVENTORY_SCENE.instantiate()
	inventory_screen.profile = profile
	inventory_screen.actor = player
	ui_layer.add_child(inventory_screen)
	inventory_screen.closed.connect(_close_inventory)
	_update_pause()

func _show_quests() -> void:
	if _any_overlay_open():
		return
	quest_screen = QUEST_SCENE.instantiate()
	quest_screen.profile = profile
	ui_layer.add_child(quest_screen)
	quest_screen.closed.connect(_close_quests)
	_update_pause()

func _any_overlay_open() -> bool:
	return is_instance_valid(inventory_screen) or is_instance_valid(quest_screen) or is_instance_valid(settings_screen) \
		or is_instance_valid(skill_screen) or is_instance_valid(magic_weapon_screen) \
		or is_instance_valid(defeat_screen) or is_instance_valid(victory_screen)

func _show_settings() -> void:
	if _any_overlay_open():
		return
	settings_screen = SETTINGS_SCENE.instantiate() as InGameSettingsScreen
	ui_layer.add_child(settings_screen)
	settings_screen.closed.connect(_close_settings)
	settings_screen.exit_level_requested.connect(_exit_level_to_map)
	settings_screen.exit_to_menu_requested.connect(_exit_level_to_menu)
	_update_pause()

func _show_skills() -> void:
	if _any_overlay_open():
		return
	skill_screen = SKILL_SCENE.instantiate()
	ui_layer.add_child(skill_screen)
	skill_screen.setup(profile, player)
	skill_screen.closed.connect(_close_skills)
	skill_screen.changed.connect(_save)
	_update_pause()

func _show_magic_weapon() -> void:
	if _any_overlay_open():
		return
	magic_weapon_screen = MAGIC_WEAPON_SCENE.instantiate()
	ui_layer.add_child(magic_weapon_screen)
	magic_weapon_screen.setup(profile, player)
	magic_weapon_screen.closed.connect(_close_magic_weapon)
	magic_weapon_screen.changed.connect(_save)
	_update_pause()

func _show_pet() -> void:
	if not _any_overlay_open():
		hud.notify("敬请期待")

func _close_inventory() -> void:
	if is_instance_valid(inventory_screen):
		inventory_screen.queue_free()
	inventory_screen = null
	_update_pause()

func _close_quests() -> void:
	if is_instance_valid(quest_screen):
		quest_screen.queue_free()
	quest_screen = null
	_update_pause()

func _close_settings() -> void:
	if is_instance_valid(settings_screen):
		settings_screen.queue_free()
	settings_screen = null
	_update_pause()

func _exit_level_to_map() -> void:
	if is_instance_valid(settings_screen):
		settings_screen.queue_free()
	settings_screen = null
	get_tree().paused = false
	profile.detach_actor()
	if save_store != null:
		save_store.save_data(profile.serialize())
	var map := MapScreen.create_for_profile(profile, save_store)
	get_tree().root.add_child(map)
	get_tree().current_scene = map
	queue_free()

func _exit_level_to_menu() -> void:
	if is_instance_valid(settings_screen):
		settings_screen.queue_free()
	settings_screen = null
	get_tree().paused = false
	profile.detach_actor()
	if save_store != null:
		save_store.save_data(profile.serialize())
	var menu: Node = load("res://Scene/UI/MainMenu.tscn").instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	queue_free()

func _close_skills() -> void:
	if is_instance_valid(skill_screen):
		skill_screen.queue_free()
		skill_screen = null
	_update_pause()

func _close_magic_weapon() -> void:
	if is_instance_valid(magic_weapon_screen):
		magic_weapon_screen.queue_free()
	magic_weapon_screen = null
	_update_pause()

func _toggle_pause() -> void:
	if is_instance_valid(defeat_screen) or is_instance_valid(victory_screen):
		return
	if is_instance_valid(inventory_screen):
		_close_inventory()
	elif is_instance_valid(quest_screen):
		_close_quests()
	elif is_instance_valid(settings_screen):
		_close_settings()
	elif is_instance_valid(skill_screen):
		_close_skills()
	elif is_instance_valid(magic_weapon_screen):
		_close_magic_weapon()
	else:
		_manual_pause = not _manual_pause
		_update_pause()

func _update_pause() -> void:
	get_tree().paused = _manual_pause or _any_overlay_open()
	if is_instance_valid(hud):
		hud.visible = not _any_overlay_open()
	if is_instance_valid(player):
		player.clear_command()

func _exit_tree() -> void:
	profile.detach_actor()
	get_tree().paused = false

func _on_enemy_defeated(monster_id: int, _position: Vector2) -> void:
	profile.progression.reward(5 + monster_id, 1 + monster_id)
	profile.quests.record(&"enemy_defeated", StringName("monster_%d" % monster_id))
	_try_drop()
	if is_instance_valid(hud):
		hud.notify("击败妖怪，获得历练")

func _on_stage_cleared(stage: int) -> void:
	if is_instance_valid(hud):
		hud.notify("第 %d 区域已肃清，前路开启" % stage)

func _on_player_died() -> void:
	# 老项目：死亡动画播完约 1.5 秒后进入战败界面。
	await get_tree().create_timer(1.5, false, true).timeout
	if not is_instance_valid(player) or is_instance_valid(defeat_screen) or is_instance_valid(victory_screen):
		return
	_show_defeat()

func _show_defeat() -> void:
	defeat_screen = DEFEAT_SCENE.instantiate() as DefeatScreen
	defeat_screen.permanent_refusal = profile.permanent_dark_power_refusal
	defeat_screen.reward_claimed = profile.dark_power_reward_claimed
	ui_layer.add_child(defeat_screen)
	defeat_screen.map_requested.connect(_exit_level_to_map)
	defeat_screen.retry_requested.connect(_retry_level)
	defeat_screen.dark_power_requested.connect(_on_dark_power_requested)
	defeat_screen.permanent_refusal_requested.connect(_on_permanent_refusal_requested)
	defeat_screen.reward_requested.connect(_on_dark_power_reward_requested)
	_update_pause()

func _on_dark_power_requested() -> void:
	if profile.inventory.create_item(&"xczg", _drop_rng) == null:
		defeat_screen.get_node("text").text = "背包空间不足，无法领取力量。"
		return
	_save()

func _on_permanent_refusal_requested() -> void:
	profile.permanent_dark_power_refusal = true
	_save()

func _on_dark_power_reward_requested() -> void:
	if profile.inventory.item_ids().size() + 37 > profile.inventory.capacity:
		defeat_screen.reward_claimed = false
		defeat_screen.get_node("text").text = "背包空间不足，无法领取奖励。"
		return
	for id: StringName in [&"bsd_5", &"mpyj"]:
		profile.inventory.create_item(id, _drop_rng)
	for id: StringName in [&"xydxq", &"qhs_4", &"qhs_3", &"qhs_2", &"qhs_1"]:
		var count := 3 if id == &"xydxq" else 8
		for index in count:
			profile.inventory.create_item(id, _drop_rng)
	profile.dark_power_reward_claimed = true
	_save()

func _close_defeat() -> void:
	if is_instance_valid(defeat_screen):
		defeat_screen.queue_free()
	defeat_screen = null
	_update_pause()

func _retry_level() -> void:
	if is_instance_valid(defeat_screen):
		defeat_screen.queue_free()
	defeat_screen = null
	if is_instance_valid(victory_screen):
		victory_screen.queue_free()
	victory_screen = null
	_manual_pause = false
	_update_pause()
	_load_level(world.definition.id)

func _on_level_completed() -> void:
	profile.last_level = world.definition.id
	profile.progression.complete_level(String(world.definition.id))
	profile.progression.reward(60, 25)
	_try_drop(true)
	profile.quests.record(&"level_completed", world.definition.id)
	_save()
	if is_instance_valid(victory_screen) or is_instance_valid(defeat_screen):
		return
	_show_victory()

func _show_victory() -> void:
	victory_screen = VICTORY_SCENE.instantiate() as VictoryScreen
	victory_screen.report = _build_level_report()
	ui_layer.add_child(victory_screen)
	victory_screen.map_requested.connect(_exit_level_to_map)
	victory_screen.retry_requested.connect(_retry_level)
	_update_pause()

func _build_level_report() -> LevelReport:
	var report := LevelReport.new()
	report.begin_time = _level_began_at
	report.end_time = Time.get_datetime_string_from_system(false, true)
	report.elapsed_seconds = maxi(0, (Time.get_ticks_msec() - _level_started_msec) / 1000)
	report.hp_percent = 0.0
	report.maximum_combo = 0
	report.received_hits = 0
	if is_instance_valid(player):
		report.hp_percent = snappedf(player.combatant.health.current / maxf(1.0, player.combatant.health.maximum) * 100.0, 0.01)
	if encounter != null:
		report.maximum_combo = encounter.maximum_combo
		report.received_hits = encounter.received_hits
		report.total_damage_received = encounter.total_damage_received
		report.total_damage_dealt = encounter.total_damage_dealt
		report.landed_hits = encounter.landed_hits
	report.star_rating = _rate_level(report.elapsed_seconds, report.hp_percent, report.received_hits)
	return report

## 老项目 victory.gd::PDpj 的评价规则：用时越短、剩余血量越高星级越高。
static func _rate_level(elapsed_seconds: int, hp_percent: float, received_hits: int) -> int:
	var minutes := elapsed_seconds / 60
	if minutes <= 2 and received_hits == 0 and hp_percent >= 95.0:
		return 5
	match minutes:
		0, 1, 2, 3:
			if hp_percent >= 85.0:
				return 4
			if hp_percent >= 75.0:
				return 3
			if hp_percent >= 65.0:
				return 2
			return 1
		4:
			if hp_percent >= 85.0:
				return 3
			if hp_percent >= 65.0:
				return 2
			return 1
		5:
			if hp_percent >= 75.0:
				return 2
			if hp_percent >= 65.0:
				return 1
			return 1
		_:
			if hp_percent >= 85.0:
				return 2
			return 1

func _try_drop(guaranteed: bool = false) -> void:
	if world == null or world.definition == null or world.definition.drop_ids.is_empty():
		return
	if not guaranteed and _drop_rng.randf() > 0.2:
		return
	var index := _drop_rng.randi_range(0, world.definition.drop_ids.size() - 1)
	var id := world.definition.drop_ids[index]
	var item := profile.inventory.create_item_with_context(id, ItemRollContext.new(_drop_rng, &"level_drop"))
	if item != null and is_instance_valid(hud):
		var definition := profile.catalog.get_definition(id)
		hud.notify("获得掉落：%s" % (definition.metadata().get("名字", id) if definition != null else id))

func _save() -> void:
	profile.last_level = world.definition.id if world.definition != null else profile.last_level
	if not save_store.save_data(profile.serialize()) and is_instance_valid(hud):
		hud.notify(save_store.last_error)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
		get_tree().quit()
