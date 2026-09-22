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
	_test_normal_attack()
	_test_interruption(false, false)
	_test_interruption(false, true)
	_test_interruption(true, false)
	_test_interruption(true, true)
	await _test_ice_wave()
	print("PLAYER ATTACK TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _player(world: Node2D) -> CombatActor:
	var player := load("res://actors/player.tscn").instantiate() as CombatActor
	world.add_child(player)
	player.get_node("PlayerInput").set_physics_process(false)
	player.set_physics_process(false)
	player.motor.gravity = 0.0
	return player

func _attacks(world: Node2D) -> Array[TimelineAttack]:
	var result: Array[TimelineAttack] = []
	for child in world.get_children():
		if child is TimelineAttack:
			result.append(child)
	return result

func _test_normal_attack() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var player := _player(world)
	var view: ActorView = player.get_node("ActorView")
	check(not player.debug_draw and view.body != null, "实际玩家默认使用原图集并隐藏方框")
	check(player.attack(), "实际玩家开始普攻")
	view._process(0.0)
	check(view.body.animation == &"hit1" and view.weapon.animation == &"hit1", "普攻身体和武器播放 hit1")
	player._physics_process(0.19)
	check(_attacks(world).is_empty(), "普攻在 0.2 秒前摇结束前不发射")
	player._physics_process(0.02)
	var attacks := _attacks(world)
	check(attacks.size() == 1 and attacks[0].animation_name == &"Role2Bullet1", "普攻在原版释放时刻生成法术")
	check(player.get_node_or_null("Melee") == null, "唐僧普攻不生成通用近战矩形")
	check(attacks[0].position == Vector2(10, -26), "普攻释放点保持原坐标的脚底换算")
	check(attacks[0].payload.damage_type == HitData.DamageType.MAGIC, "唐僧普攻进入魔法伤害管线")
	view.body.frame = view.body.sprite_frames.get_frame_count(&"hit1") - 1
	view.weapon.frame = view.weapon.sprite_frames.get_frame_count(&"hit1") - 1
	player._physics_process(0.35)
	check(player.attack(), "前次普攻结束后可以再次开始")
	view._process(0.0)
	check(view.body.frame == 0 and view.weapon.frame == 0, "连续相同动作即使没有渲染 FREE 也从首帧重播")
	world.free()

func _test_interruption(skill: bool, death: bool) -> void:
	var world := Node2D.new()
	root.add_child(world)
	var player := _player(world)
	check(player.use_ability(&"ice_dragon_wave") if skill else player.attack(), "可开始待打断动作")
	player._physics_process(0.1)
	if death:
		player.combatant.health.damage(player.combatant.health.maximum)
	else:
		var enemy := Combatant.new(StatDefinition.new(), 2)
		var hit := HitData.from_attacker(enemy, 1.0)
		hit.ignores_defense = true
		hit.hitstun = 0.3
		CombatResolver.resolve(hit, player.combatant)
	player._physics_process(1.0)
	check(_attacks(world).is_empty(), "%s在%s后取消未释放法术" % ["技能" if skill else "普攻", "死亡" if death else "受击"])
	world.free()

func _test_ice_wave() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var player := _player(world)
	check(player.use_ability(&"ice_dragon_wave"), "实际玩家开始冰龙波")
	player._physics_process(0.5)
	check(_attacks(world).is_empty(), "冰龙波保留 0.5001 秒释放延迟")
	player._physics_process(0.001)
	var attacks := _attacks(world)
	check(attacks.size() == 1 and attacks[0].animation_name == &"Role2Bullet2", "冰龙波生成原版动画场景")
	var wave := attacks[0]
	check(wave.position == Vector2(15, -41), "冰龙波保持原释放高度")
	var target := Hurtbox.new()
	var target_stats := StatDefinition.new()
	target_stats.max_hp = 1000.0
	target.combatant = Combatant.new(target_stats, 2)
	target.position = Vector2(440, -41)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1000, 80)
	collider.shape = shape
	target.add_child(collider)
	world.add_child(target)
	var hits: Array[float] = []
	target.combatant.damaged.connect(func(amount: float, _stun: float): hits.append(amount))
	for frame_index in range(48):
		await physics_frame
	check(hits.size() >= 3, "冰龙波原命中窗口在物理引擎中造成多段伤害")
	check(is_instance_valid(wave) and wave.hitbox.get_node("Collion").position.x < -450.0, "冰龙波判定按原轨道向前推进")
	for frame_index in range(40):
		await physics_frame
	check(not is_instance_valid(wave), "冰龙波沿原时间轨道结束并释放")
	world.free()
