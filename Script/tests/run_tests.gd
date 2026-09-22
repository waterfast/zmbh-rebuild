extends SceneTree
## 无外部测试插件。失败返回非零，既验证规则也验证实际物理碰撞。

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func frames(count: int) -> void:
	for index in range(count):
		await physics_frame
	await process_frame

func _run() -> void:
	_test_rules()
	await _test_scene()
	print("REFACTOR TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _test_rules() -> void:
	var definition := StatDefinition.new()
	var attacker := Combatant.new(definition, 1)
	var target := Combatant.new(definition, 2)
	attacker.stats.set_modifier(&"equipment_a", &"attack", 10.0, 0.1)
	attacker.stats.set_modifier(&"equipment_b", &"attack", 0.0, 0.2)
	check(is_equal_approx(attacker.stats.value(&"attack"), 39.0), "属性加法与百分比")
	attacker.stats.remove_source(&"equipment_a")
	check(is_equal_approx(attacker.stats.value(&"attack"), 24.0), "按来源撤销属性")
	check(definition.attack == 20.0 and target.stats.value(&"attack") == 20.0, "共享 Resource 不串改")
	var hit := HitData.from_attacker(attacker, 20.0)
	check(CombatResolver.resolve(hit, target) == 19.0, "原版防御比率结算")
	check(CombatResolver.resolve(hit, attacker) == 0.0, "友军不受伤")
	var armor: BuffDefinition = load("res://content/super_armor.tres")
	target.buffs.add(armor, &"a")
	target.buffs.add(armor, &"b")
	target.buffs.remove_source(&"a")
	check(target.buffs.has_tag(&"super_armor"), "移除单来源不影响其他霸体")
	var observed: Array[float] = []
	target.damaged.connect(func(_amount: float, stun: float): observed.append(stun))
	CombatResolver.resolve(hit, target)
	check(observed.back() == 0.0 and target.health.current == 62.0, "霸体免硬直但不免伤")
	target.buffs.tick(3.0, target)
	check(not target.buffs.has_tag(&"super_armor"), "霸体到期")
	var poison: BuffDefinition = load("res://content/poison.tres")
	target.buffs.add(poison, &"poison", hit)
	target.buffs.tick(5.5, target)
	check(target.health.current == 42.0, "长帧补齐 5 次中毒，不多扣到期伤害")
	target.buffs.tick(2.0, target)
	check(target.health.current == 42.0, "中毒移除后不再扣血")
	var deaths: Array[int] = []
	target.health.died.connect(func(): deaths.append(1))
	target.health.damage(1000.0)
	target.health.damage(1000.0)
	target.health.heal(100.0)
	check(deaths.size() == 1 and target.health.current == 0.0, "死亡只通知一次且普通治疗不能复活")
	check(CombatResolver.resolve(hit, target) == 0.0, "尸体不重复结算")
	var action := ActionState.new()
	var movement := LocomotionState.new()
	action.try_start(ActionState.State.ATTACK, 0.3)
	movement.update(false, Vector2(0, -100))
	check(action.current == ActionState.State.ATTACK and movement.current == LocomotionState.State.JUMP, "空中攻击两个状态并存")
	action.hurt(0.2)
	check(not action.try_start(ActionState.State.ATTACK, 0.3), "受击不能开始普攻")
	action.die()
	action.tick(10.0)
	action.hurt(1.0)
	check(action.current == ActionState.State.DEAD, "死亡终态不能被计时或受击覆盖")
	var ability: AbilityDefinition = load("res://content/ice_dragon_wave.tres")
	var controller := AbilityController.new(100.0)
	controller.grant(ability, &"character")
	controller.grant(ability, &"weapon")
	controller.remove_source(&"weapon")
	check(controller.has_ability(ability.id), "同技能多个来源只撤销指定来源")
	var free_action := ActionState.new()
	check(controller.try_cast(ability.id, free_action) and controller.mp == 75.0, "施法扣蓝")
	check(not controller.try_cast(ability.id, free_action) and controller.mp == 75.0, "失败施法不重复扣蓝")
	controller.remove_source(&"character")
	controller.grant(ability, &"new_weapon")
	free_action.tick(1.0)
	check(not controller.try_cast(ability.id, free_action), "重新授予不能绕过冷却")
	controller.tick(2.4)
	check(controller.try_cast(ability.id, free_action), "冷却结束可施法")
	controller.remove_source(&"new_weapon")
	check(not controller.has_ability(ability.id), "最后来源移除技能消失")
	var no_mana := AbilityController.new(0.0)
	no_mana.grant(ability, &"character")
	var idle := ActionState.new()
	check(not no_mana.try_cast(ability.id, idle) and idle.current == ActionState.State.FREE, "蓝量不足不锁定动作")
	var poisoned := Combatant.new(definition, 2)
	var second_attacker := Combatant.new(definition, 1)
	var second_hit := HitData.from_attacker(second_attacker, 1.0)
	hit.buff = poison
	second_hit.buff = poison
	second_hit.ignores_defense = true
	CombatResolver.resolve(hit, poisoned)
	CombatResolver.resolve(second_hit, poisoned)
	poisoned.buffs.remove_source(hit.source_id)
	var before_tick := poisoned.health.current
	poisoned.buffs.tick(1.0, poisoned)
	check(poisoned.health.current == before_tick - 4.0, "攻击附加 Buff 按不同攻击者分离来源")
	poisoned.buffs.add(poison, second_hit.source_id, second_hit)
	poisoned.buffs.tick(1.0, poisoned)
	check(poisoned.health.current == before_tick - 8.0, "同来源中毒刷新不重复叠层")
	var weak_source: WeakRef = weakref(attacker)
	attacker = null
	check(weak_source.get_ref() == null, "攻击快照不保留攻击者")

func _test_scene() -> void:
	var arena: Node2D = load("res://demo/arena.tscn").instantiate()
	root.add_child(arena)
	var player: CombatActor = arena.player
	var enemy: CombatActor = arena.enemy
	# 这里专测通用近战与匀速飞行物；原唐僧动作由独立迁移测试覆盖。
	player.normal_attack = null
	var projectile_fixture := AbilityDefinition.new()
	projectile_fixture.id = &"test_projectile"
	projectile_fixture.projectile_scene = load("res://actors/projectile.tscn")
	player.abilities.grant(projectile_fixture, &"test")
	player.get_node("PlayerInput").set_physics_process(false)
	enemy.get_node("EnemyAI").set_physics_process(false)
	await frames(6)
	check(player.is_on_floor(), "实际碰撞落地")
	var start_x := player.position.x
	player.move_intent = 1.0
	await frames(6)
	check(player.position.x > start_x, "Motor 实际水平移动")
	player.move_intent = 0.0
	player.jump_intent = true
	await frames(3)
	check(player.velocity.y < 0.0 and player.locomotion.current == LocomotionState.State.JUMP, "实际起跳")
	player.jump_intent = true
	var initial_velocity := player.velocity.y
	await frames(2)
	check(player.velocity.y > initial_velocity, "空中不能再次起跳")
	await frames(75)
	check(player.is_on_floor(), "跳跃结束落地")
	enemy.position = player.position + Vector2(45, 0)
	await frames(3)
	player.facing = 1.0
	player.attack()
	await frames(12)
	check(enemy.combatant.health.current == 31.0, "真实 Hitbox 命中一次，不逐帧重复伤害")
	await frames(15)
	enemy.position = player.position + Vector2(160, 0)
	player.use_ability(&"test_projectile")
	await frames(35)
	check(is_equal_approx(enemy.combatant.health.current, 16.0), "真实匀速飞行物碰撞扣血")
	await frames(100)
	var projectiles := 0
	for child in arena.get_children():
		if child is CombatProjectile:
			projectiles += 1
	check(projectiles == 0, "飞行物命中或超时回收")
	enemy.position = player.position + Vector2(120, 0)
	enemy.get_node("EnemyAI").set_physics_process(true)
	var hp := player.combatant.health.current
	await frames(120)
	check(player.combatant.health.current < hp, "AI 接近并用同一伤害入口攻击玩家")
	enemy.combatant.health.damage(1000.0)
	await frames(50)
	check(not is_instance_valid(enemy), "敌人死亡后回收节点")
	player.combatant.health.damage(1000.0)
	check(not player.attack() and not player.use_ability(&"ice_dragon_wave"), "死亡不能攻击或施法")
	arena.queue_free()
	await frames(3)
	await _test_cleanup()

func _test_cleanup() -> void:
	var baseline_nodes := get_node_count()
	var baseline_orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for cycle in range(3):
		var arena: Node2D = load("res://demo/arena.tscn").instantiate()
		root.add_child(arena)
		var player: CombatActor = arena.player
		player.get_node("PlayerInput").set_physics_process(false)
		arena.enemy.get_node("EnemyAI").set_physics_process(false)
		player.facing = -1.0
		player.use_ability(&"ice_dragon_wave")
		for spawn_index in range(5):
			arena.spawn_enemy()
			arena.enemy.get_node("EnemyAI").set_physics_process(false)
			await frames(2)
		await frames(115)
		var shots := 0
		for child in arena.get_children():
			if child is CombatProjectile:
				shots += 1
		check(shots == 0, "未命中飞行物超时回收，第 %d 轮" % cycle)
		arena.queue_free()
		await frames(3)
		check(get_node_count() == baseline_nodes, "反复建场景与重生后节点恢复基线，第 %d 轮" % cycle)
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == baseline_orphans, "反复运行不增加孤儿节点")
