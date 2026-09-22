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
	var attacker := Combatant.new(StatDefinition.new(), 1)
	var normal := _spawn("res://Scene/Combat/TangSanzangNormal.tscn", attacker, 1.0)
	var sprite: AnimatedSprite2D = normal.get_node("Middle/BulletPlayer")
	var shape: CollisionShape2D = normal.get_node("Middle/HitBox/Collion")
	check(sprite.sprite_frames.get_frame_count(&"Role2Bullet1") == 24, "普攻保留原版 24 帧")
	check(sprite.sprite_frames.get_animation_names().size() == 1, "普攻资源不加载其他法术帧")
	check(sprite.offset == Vector2(-200, 0), "普攻保留原图集偏移")
	check(shape.shape.size == Vector2(107, 32), "普攻保留原碰撞尺寸")
	check(not shape.disabled, "普攻从初始帧即可命中")
	normal.animation_player.advance(0.2)
	check(shape.position.is_equal_approx(Vector2(-86, 0)), "普攻判定沿原轨道移动")
	check(shape.global_position.x > normal.global_position.x, "向右释放时图集和碰撞一起镜像")
	check(normal.position == Vector2.ZERO, "长图集法术根节点不额外匀速移动")
	var normal_ref: WeakRef = weakref(normal)
	normal.animation_player.advance(0.71)
	await process_frame
	check(normal_ref.get_ref() == null, "普攻在原版 0.9 秒回收")
	var wave := _spawn("res://Scene/Combat/IceDragonWave.tscn", attacker, -1.0)
	sprite = wave.get_node("Middle/BulletPlayer")
	shape = wave.get_node("Middle/HitBox/Collion")
	check(sprite.sprite_frames.get_frame_count(&"Role2Bullet2") == 47, "冰龙波保留原版 47 帧")
	check(sprite.sprite_frames.get_animation_names().size() == 1, "冰龙波资源不加载其他法术帧")
	check(sprite.offset == Vector2(-450, 0), "冰龙波保留原图集偏移")
	check(shape.shape.size == Vector2(122, 58), "冰龙波保留原碰撞尺寸")
	var victim := Hurtbox.new()
	victim.combatant = Combatant.new(StatDefinition.new(), 2)
	root.add_child(victim)
	wave.hitbox._on_area_entered(victim)
	var health_after_hit := victim.combatant.health.current
	wave.hitbox._on_area_entered(victim)
	check(victim.combatant.health.current == health_after_hit, "单个命中窗口去重")
	wave.animation_player.advance(0.15)
	check(shape.disabled, "冰龙波在 0.1 秒关闭首个命中窗口")
	wave.animation_player.advance(0.1)
	check(not shape.disabled, "冰龙波在 0.2 秒重新开放窗口")
	wave.hitbox._on_area_entered(victim)
	check(victim.combatant.health.current < health_after_hit, "后续窗口允许再次命中")
	check(shape.global_position.x < wave.global_position.x, "向左释放保留原判定朝向")
	var wave_ref: WeakRef = weakref(wave)
	wave.animation_player.advance(1.06)
	await process_frame
	check(wave_ref.get_ref() == null, "冰龙波在原版 1.3 秒回收")
	victim.free()
	await _test_physics_collision(attacker)
	print("TIMELINE ATTACK TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _spawn(path: String, attacker: Combatant, direction: float) -> TimelineAttack:
	var attack := load(path).instantiate() as TimelineAttack
	attack.payload = HitData.from_attacker(attacker, 20.0)
	attack.payload.damage_type = HitData.DamageType.MAGIC
	attack.facing = direction
	root.add_child(attack)
	attack.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return attack

func _test_physics_collision(attacker: Combatant) -> void:
	var target := Hurtbox.new()
	target.combatant = Combatant.new(StatDefinition.new(), 2)
	target.position = Vector2(200, 0)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 48)
	collider.shape = shape
	target.add_child(collider)
	root.add_child(target)
	var attack := _spawn("res://Scene/Combat/TangSanzangNormal.tscn", attacker, 1.0)
	attack.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	var original_health := target.combatant.health.current
	for frame_index in range(10):
		await physics_frame
	check(target.combatant.health.current == original_health, "移动判定到达前不会提前命中远处目标")
	for frame_index in range(30):
		await physics_frame
	check(target.combatant.health.current < original_health, "原动画轨道的碰撞在物理引擎中实际命中")
	var health_after_hit := target.combatant.health.current
	for frame_index in range(30):
		await physics_frame
	check(target.combatant.health.current == health_after_hit, "普攻实际碰撞只伤害同目标一次")
	check(not is_instance_valid(attack), "实际播放结束释放攻击节点")
	target.free()
