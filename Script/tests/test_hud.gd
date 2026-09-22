extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	GameInputBindings.install()
	var player: CombatActor = load("res://actors/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player.get_node("PlayerInput").set_physics_process(false)
	var hud: GameHUD = load("res://Scene/UI/GameHUD.tscn").instantiate()
	root.add_child(hud)
	var progression := PlayerProgression.new()
	hud.bind(player, progression, "花果山")
	check(hud.get_node_or_null("AreaName") == null and hud.get_node_or_null("Notice") == null, "不添加非原版HUD文字层")
	hud.notify("测试提示", 0.0)
	var notice := hud.get_child(hud.get_child_count() - 1) as GameNotification
	check(notice != null and notice.scene_file_path == "res://Scene/show_text/Message_show.tscn", "HUD通知复用原提示场景")
	check(notice.get_node("MessagePlayer").has_animation("MessageShow"), "保留原通知动画")
	check(hud.get_node(GameHUD.MENU.trim_suffix("/")).position == Vector2(90, 531), "保留原底部菜单坐标")
	check(hud.get_node(GameHUD.STATUS.trim_suffix("/")).position == Vector2(116, 44), "保留原状态栏坐标")
	check(not hud.get_node("RoleInformation/roleLayer") is CanvasLayer, "HUD使用应用统一显示层")
	check(hud._hp.get_parent().name == &"role_hp_mp_exp", "血条绑定旧场景节点")
	check(hud._hp.max_value == player.combatant.health.maximum, "生命上限来自战斗组件")
	player.combatant.health.damage(7.0)
	check(hud._hp.value == player.combatant.health.current, "受伤信号立即刷新血条")
	check(hud._skills.count(&"ice_dragon_wave") == 1 and hud._skills.count(&"") == 4, "只显示实际授予的冰龙波")
	var slot_index := hud._skills.find(&"ice_dragon_wave")
	var slot: TextureRect = hud._slots[slot_index]
	check(slot.name == &"U" and slot.get_node("Y").text == "U", "技能键位由当前InputSource匹配原U槽")
	check(slot.tooltip_text == "冰龙波" and slot.texture.resource_path.ends_with("/blb.png"), "图标和名称来自技能定义")
	check(hud._slots[0].mouse_filter == Control.MOUSE_FILTER_IGNORE, "空技能槽不接收点击")
	var mana := player.abilities.mp
	hud._request_skill(&"ice_dragon_wave")
	check(player.abilities.mp == mana - 25.0, "HUD施法调用同一技能控制器")
	hud._process(0.1)
	check(not slot.get_node("TimeText").text.is_empty(), "原冷却文本绑定真实冷却")
	var metadata := AbilityDefinition.new()
	metadata.id = &"unmigrated_test"
	metadata.migration_status = "metadata_only"
	player.abilities.grant(metadata, &"test")
	var disabled_index := hud._skills.find(metadata.id)
	check(disabled_index >= 0 and hud._slots[disabled_index].mouse_filter == Control.MOUSE_FILTER_IGNORE, "只迁移元数据的技能禁用点击")
	player.abilities.remove_source(&"test")
	check(not hud._skills.has(metadata.id), "撤销授予立即清空槽位")
	player.abilities.remove_source(&"character")
	check(hud._skills.count(&"") == 5, "失去最后技能来源不残留图标")
	hud.queue_free()
	player.queue_free()
	await process_frame
	print("HUD TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
