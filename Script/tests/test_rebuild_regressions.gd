extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	await _slope()
	await _progression_ui()
	await _actions()
	print("REBUILD REGRESSION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func _slope() -> void:
	var world := Node2D.new()
	root.add_child(world)
	world.add_child(load("res://content/world/geometry/level_1.tscn").instantiate())
	var player: CombatActor = load("res://actors/player.tscn").instantiate()
	world.add_child(player)
	player.get_node("PlayerInput").set_physics_process(false)
	player.position = Vector2(920, 385)
	for index in 60:
		await physics_frame
	player.move_intent = 1
	var highest := player.position.y
	for index in 170:
		await physics_frame
		highest = minf(highest, player.position.y)
	print("SLOPE ", player.position, " highest=", highest, " normal=", player.get_wall_normal())
	check(player.position.x > 1450, "第一关原碰撞：无需跳跃从左侧走过第一个坡")
	check(highest < 440, "确实登上坡顶而非穿过地形")
	player.move_intent = -1
	for index in 170:
		await physics_frame
	check(player.position.x < 990, "第一关原碰撞：从右侧返回也能过坡")
	world.queue_free()
	await process_frame
func _progression_ui() -> void:
	var app: GameApp = load("res://app/game_app.tscn").instantiate()
	app.load_saved_profile = false
	app.save_store = SaveStore.new("user://rebuild_verification_only.json")
	app.profile.start_new()
	app.profile.select_character(1)
	root.add_child(app)
	app.encounter.set_physics_process(false)
	var profile := app.profile
	var skill := profile.ability_catalog.resolve(&"slz")
	check(not app.player.abilities.has_ability(&"slz"), "新档未学技能不应被授予")
	check(not profile.skills.learn(skill, 1, profile.progression).is_empty(), "余额不足禁止学习")
	profile.progression.gold = 1000000
	check(profile.skills.learn(skill, 1, profile.progression).is_empty(), "学习成功")
	check(profile.progression.gold == 999900 and app.player.abilities.has_ability(&"slz"), "学习精确扣费且即时授予")
	check(not profile.skills.learn(skill, 1, profile.progression).is_empty(), "主动技能一级上限")
	check(profile.skills.assign(4, skill, 1), "已学技能可分配第五槽")
	check(app.player.get_node("PlayerInput").source.slots.get(&"ability_4") == &"slz", "键位实际驱动输入")
	check(profile.skills.learn_passive(0, profile.progression).is_empty(), "通用被动可学习")
	check(app.player.combatant.stats.value(&"max_hp") >= 280, "被动生命立即生效")
	var restored := PlayerProfile.new()
	check(restored.restore(profile.serialize()), "新技能存档可恢复")
	check(restored.skills.level(&"slz") == 1 and restored.skills.slots.get("4") == "slz", "等级和键位保存")
	var rng := RandomNumberGenerator.new()
	var relic := profile.inventory.create_item(&"dshl", rng)
	check(profile.equipment.equip(relic.uid), "装备法宝")
	var service := RelicProgression.new(profile.inventory, profile.progression)
	var before := profile.progression.gold
	check(service.upgrade(relic.uid).is_empty() and relic.enhancement == 1, "法宝升级")
	check(profile.progression.gold == before - 1000 and service.cost(relic) == 4000, "原版法宝升级费用")
	var attack := app.player.combatant.stats.value(&"attack")
	service.upgrade(relic.uid)
	check(app.player.combatant.stats.value(&"attack") > attack, "升级后装备属性刷新")
	check(not service.refine(relic.uid, &"growth").is_empty(), "无材料禁止洗炼")
	profile.inventory.create_item(&"czlxls", rng)
	check(service.refine(relic.uid, &"growth").is_empty(), "成长洗炼消耗材料")
	app._show_pet()
	check(not app._any_overlay_open() and not paused, "宠物入口只提示敬请期待，不打开占位面板")
	app._show_magic_weapon()
	await process_frame
	check(app.magic_weapon_screen is MagicWeaponUpgrade, "HUD法宝入口打开成长窗口")
	check(app.magic_weapon_screen.position.distance_to(Vector2(470,295)) < 5, "法宝窗口居中")
	check(app.magic_weapon_screen.get_node("BG/bg_2/m_level").text == "2", "法宝升级信息绑定实例")
	app.magic_weapon_screen._on_szfb_pressed()
	await process_frame
	check(app.magic_weapon_screen._dialog is MagicWeaponPanel, "实战技能选择保留为子入口")
	app._close_magic_weapon()
	await process_frame
	app._show_skills()
	await process_frame
	check(app.skill_screen._content.has_node("ScrollContainer/HBoxContainer/sk_lv/Skill_10"), "十个角色技能使用原滚动场景")
	app.skill_screen._on_bd_skill_pressed()
	check(app.skill_screen._content.has_node("HBoxContainer/Up_level/up_6"), "通用被动原场景")
	app._close_skills()
	app.queue_free()
	await process_frame
func _actions() -> void:
	for character in [1,3,4,5]:
		var player: CombatActor = load("res://actors/player.tscn").instantiate()
		root.add_child(player)
		player.get_node("PlayerInput").set_physics_process(false)
		player.set_physics_process(false)
		player.get_node("ActorView").set_skin(CharacterAbilityRegistry.skin_id(character))
		CharacterAbilityRegistry.register_actor(player, CharacterAbilityRegistry.skin_id(character))
		check(player.attack(), "角色%d普通攻击可启动" % character)
		await process_frame
		check(is_instance_valid(player._action_timeline), "角色%d原动画已装配" % character)
		if is_instance_valid(player._action_timeline):
			check(player._action_timeline.get_node("Player").is_playing(), "原动画正在播放")
		player._on_damaged(1, 0.2)
		await process_frame
		check(not is_instance_valid(player._action_timeline), "受击立即取消原动画命中窗口")
		check(player.get_node("ActorView").visible, "受击恢复状态表现")
		player.queue_free()
		await process_frame
