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
	var player := load("res://actors/player.tscn").instantiate() as CombatActor
	root.add_child(player)
	player.get_node("PlayerInput").set_physics_process(false)
	player.set_physics_process(false)
	var view := player.get_node_or_null("ActorView") as ActorView
	check(view != null and view.actor == player, "角色场景直接绑定 ActorView")
	check(not player.debug_draw, "角色默认隐藏调试方块")
	if view != null:
		check(view.body != null and view.body.sprite_frames != null, "场景加载后自动创建角色动画")
		for skin: StringName in [&"hero_1", &"tang_sanzang", &"hero_3", &"hero_4", &"hero_5"]:
			check(view.set_skin(skin), "原版角色皮肤可加载：%s" % skin)
			var attack_animation := &"hit1_1" if skin == &"hero_4" else &"hit1"
			check(view.body.sprite_frames.get_frame_count(attack_animation) > 0, "原版角色普攻帧存在：%s" % skin)
			_check_animation(view, ActionState.State.ATTACK, LocomotionState.State.IDLE, attack_animation)
		view.set_skin(&"tang_sanzang")
		_check_animation(view, ActionState.State.FREE, LocomotionState.State.IDLE, &"wait")
		_check_animation(view, ActionState.State.FREE, LocomotionState.State.RUN, &"run")
		_check_animation(view, ActionState.State.ATTACK, LocomotionState.State.IDLE, &"hit1")
		_check_animation(view, ActionState.State.HURT, LocomotionState.State.IDLE, &"hurt")
		_check_animation(view, ActionState.State.DEAD, LocomotionState.State.IDLE, &"death")
		view.present(ActionState.State.ATTACK, LocomotionState.State.IDLE, 1.0)
		check(view.weapon.animation == &"hit1", "唐僧武器与身体同步普攻")
		check(view.body.flip_h == view.weapon.flip_h, "身体与武器朝向一致")
		player.normal_attack = null
		check(player.attack(), "角色实际普攻成功")
		await process_frame
		check(view.body.animation == &"hit1", "场景中的 Actor 状态驱动普攻动画")
		check(not player.get_node("Melee/Visual").visible, "正式普攻隐藏调试判定框")
		player.action.tick(0.35)
		player.debug_draw = true
		check(player.attack(), "调试模式仍可普攻")
		var debug_visuals: int = 0
		for child in player.get_children():
			if child is Hitbox and child.get_node("Visual").visible:
				debug_visuals += 1
		check(debug_visuals == 1, "调试模式才显示普攻判定框")
	var enemy := load("res://actors/enemy.tscn").instantiate() as CombatActor
	root.add_child(enemy)
	enemy.get_node("EnemyAI").set_physics_process(false)
	enemy.set_physics_process(false)
	var enemy_view := enemy.get_node_or_null("ActorView") as ActorView
	check(enemy_view != null and enemy_view.actor == enemy, "怪物场景直接绑定 ActorView")
	check(not enemy.debug_draw, "怪物默认隐藏调试方块")
	if enemy_view != null:
		check(enemy_view.skin_id == &"monkey", "怪物默认加载原版小猴子皮肤")
		_check_animation(enemy_view, ActionState.State.FREE, LocomotionState.State.RUN, &"walk")
		_check_animation(enemy_view, ActionState.State.ATTACK, LocomotionState.State.IDLE, &"hit1")
		_check_animation(enemy_view, ActionState.State.HURT, LocomotionState.State.IDLE, &"hurt")
		_check_animation(enemy_view, ActionState.State.DEAD, LocomotionState.State.IDLE, &"death")
	player.free()
	enemy.free()
	print("ANIMATION TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _check_animation(view: ActorView, action: int, movement: int, expected: StringName) -> void:
	view.present(action, movement, 1.0)
	check(view.body.animation == expected, "%s 动作映射为 %s" % [view.skin_id, expected])
