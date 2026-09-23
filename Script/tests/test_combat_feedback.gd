extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var player := load("res://actors/player.tscn").instantiate() as CombatActor
	world.add_child(player)
	player.set_physics_process(false)
	player.get_node("PlayerInput").set_physics_process(false)
	var view := player.get_node("ActorView") as ActorView
	view.set_skin(&"tang_sanzang")
	player.combatant.damaged.emit(10.0, 0.3)
	await process_frame
	await process_frame
	check(_has_child(player, "SpecialEffect"), "角色受击生成随身的原 RoleBeHit 特效")
	var hit_effect := player.get_node_or_null("SpecialAffect") as SpecialEffect
	if hit_effect != null:
		var previous_position := hit_effect.global_position
		player.position.x += 20.0
		check(is_equal_approx(hit_effect.global_position.x, previous_position.x + 20.0), "受击特效随角色位移")
	check(_has_child(player, "CharacterActionTimeline"), "角色受击使用原动作轨道")
	var enemy := load("res://actors/enemy.tscn").instantiate() as CombatActor
	world.add_child(enemy)
	enemy.position = player.position + Vector2(100, 0)
	enemy.set_physics_process(false)
	enemy.get_node("EnemyAI").set_physics_process(false)
	var holy := CharacterActionCatalog.configure(AbilityCatalog.new().runtime_resolve(&"hyjj"), 1)
	check(holy.effects.size() == 1 and holy.effects[0] is HolyScriptureEffect, "九环圣经接入原版目标位置弹体")
	holy.effects[0].execute(player, holy)
	check(_has_child(world, "Hero1Bullet"), "九环圣经在敌人位置生成原版图集")
	player.combatant.health.damage(player.combatant.health.maximum)
	await process_frame
	await process_frame
	check(player.action.current == ActionState.State.DEAD and _has_child(player, "CharacterActionTimeline"), "角色死亡使用原动作轨道")
	enemy.combatant.damaged.emit(5.0, 0.2)
	check(_has_child(world, "MonsterHitEffect"), "怪物受击生成原闪光场景")
	enemy.combatant.health.damage(enemy.combatant.health.maximum)
	var enemy_view := enemy.get_node("ActorView") as ActorView
	var death_delay := minf(0.8, maxf(0.0, enemy.corpse_lifetime - 0.1))
	enemy_view._process(death_delay - 0.01)
	check(not _has_child(world, "SpecialEffect"), "怪物死亡粒子等待原动画触发点")
	enemy_view._process(0.02)
	check(_has_child(world, "SpecialEffect"), "怪物死亡粒子在遗体消失前出现")
	enemy.despawning.emit()
	check(_count_children(world, "SpecialEffect") == 1, "怪物遗体回收不会重复生成死亡粒子")
	var events := CharacterVisualEvents.for_action(2, &"jgz")
	check(events.size() == 1 and events[0].name == "AddJGZ", "角色技能按原方法轨道安排外放特效")
	CharacterVisualEvents.trigger(player, "AddJGZ")
	check(_has_child(world, "RoleSpecialEffectView"), "角色专属特效使用原场景资源")
	for name: String in ["Role2Bullet3", "Role2Bullet4", "Role2Bullet5", "Role2Bullet6", "Role3Bullet1", "Role3Bullet2", "Role3Bullet3", "Role4Bullet3", "Role4Bullet6", "Role5Bullet1", "Role5Bullet2", "Role5Bullet3", "Role5Bullet4", "Role5Bullet5"]:
		var packed := load("res://Scene/Combat/Spells/%s.tscn" % name) as PackedScene
		var spell := packed.instantiate() as TimelineAttack
		var sprite := spell.get_node("Middle/BulletPlayer") as AnimatedSprite2D
		var frames := sprite.sprite_frames
		var visible_frame := false
		if frames.has_animation(StringName(name)):
			for index in frames.get_frame_count(StringName(name)):
				visible_frame = visible_frame or frames.get_frame_texture(StringName(name), index) != null
		check(visible_frame, "%s 包含原图集可见帧" % name)
		var animation := (spell.get_node("Middle/BulletPlayers") as AnimationPlayer).get_animation(StringName(name))
		for track in animation.get_track_count():
			var track_path := String(animation.track_get_path(track))
			if not track_path.ends_with(":animation"):
				continue
			var layer := spell.get_node_or_null("Middle/" + track_path.get_slice(":", 0)) as AnimatedSprite2D
			if layer == null:
				continue
			for key in animation.track_get_key_count(track):
				var required := StringName(animation.track_get_key_value(track, key))
				check(layer.sprite_frames.has_animation(required), "%s 引用的 %s 图集动画存在" % [name, required])
		spell.free()
	for name: String in ["Role2Bullet3", "Role3Bullet1", "Role4Bullet3", "Role5Bullet1"]:
		var spell := (load("res://Scene/Combat/Spells/%s.tscn" % name) as PackedScene).instantiate() as TimelineAttack
		spell.payload = HitData.from_attacker(player.combatant, 10.0)
		world.add_child(spell)
		await process_frame
		check(spell.animation_player.current_animation == StringName(name), "%s 播放原版弹体轨道" % name)
		spell.free()
	var defeat := load("res://Scene/Level/DefeatScreen.tscn").instantiate() as DefeatScreen
	root.add_child(defeat)
	check(defeat.get_node_or_null("text/jj") != null and defeat.get_node_or_null("text/js") != null, "战败弹窗恢复原版选择按钮")
	defeat.get_node("text/jj").pressed.emit()
	check(defeat.get_node("text").text in DefeatScreen.REFUSAL_LINES, "战败选择按钮实际触发原版台词")
	var detail := load("res://Scene/Level/AfterLevelEnd.tscn").instantiate() as AfterLevelEnd
	detail.report = LevelReport.new()
	root.add_child(detail)
	check(detail.get_node_or_null("HBoxContainer/VBoxContainer/TotalHit") != null, "结算详情保留原版节点")
	var session := WorldSession.new()
	session.definition = LevelDefinition.new()
	session.definition.waves = [{"stage": 1, "monster_ids": PackedInt32Array([1])}]
	root.add_child(session)
	var encounter := StageEncounter.new()
	session.add_child(encounter)
	encounter.world = session
	encounter._living = 1
	encounter._next_spawn = 1
	var completions := [0]
	encounter.completed.connect(func() -> void: completions[0] += 1)
	encounter._on_enemy_died(enemy, 1)
	check(completions[0] == 0 and not encounter.finished, "最后怪物倒下时先保留死亡表现")
	enemy.despawning.emit()
	await create_timer(0.55).timeout
	check(completions[0] == 1 and encounter.finished, "遗体回收并播放粒子后再通关")
	world.queue_free()
	defeat.queue_free()
	detail.queue_free()
	session.queue_free()
	for index in 4:
		await process_frame
	print("COMBAT FEEDBACK TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _has_child(parent: Node, class_label: String) -> bool:
	return _count_children(parent, class_label) > 0

func _count_children(parent: Node, class_label: String) -> int:
	var count := 0
	for child in parent.get_children():
		if child.get_class() == class_label or child.get_script() != null and child.get_script().get_global_name() == class_label:
			count += 1
	return count
