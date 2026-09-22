extends Node2D
## 演示装配、调试按键和 HUD 都留在关卡，不能进入通用角色类。

const PLAYER = preload("res://actors/player.tscn")
const ENEMY = preload("res://actors/enemy.tscn")
const POISON = preload("res://content/poison.tres")
const ARMOR = preload("res://content/super_armor.tres")
var player: CombatActor
var enemy: CombatActor
var _status: Label
var _hud_elapsed: float = 0.0

func _ready() -> void:
	_setup_input()
	_add_wall(Vector2(480, 490), Vector2(960, 40))
	_add_wall(Vector2(-10, 270), Vector2(20, 540))
	_add_wall(Vector2(970, 270), Vector2(20, 540))
	player = PLAYER.instantiate()
	player.position = Vector2(260, 470)
	add_child(player)
	spawn_enemy()
	_create_hud()

func spawn_enemy() -> void:
	if is_instance_valid(enemy):
		enemy.queue_free()
	enemy = ENEMY.instantiate()
	enemy.position = Vector2(650, 470)
	add_child(enemy)
	enemy.get_node("EnemyAI").target = player

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if Input.is_action_just_pressed("spawn_enemy"):
		spawn_enemy()
	if Input.is_action_just_pressed("armor") and player.combatant.health.is_alive():
		player.combatant.buffs.add(ARMOR, &"demo")
	if Input.is_action_just_pressed("poison") and is_instance_valid(enemy) and enemy.combatant.health.is_alive():
		var hit := HitData.from_attacker(player.combatant, 0.0)
		enemy.combatant.buffs.add(POISON, &"demo", hit)
	if Input.is_action_just_pressed("restore_mp"):
		player.abilities.restore_mp(100.0)
	_hud_elapsed += delta
	if _hud_elapsed >= 0.1:
		_hud_elapsed = 0.0
		_update_hud()

func _setup_input() -> void:
	var bindings := {
		"move_left": KEY_A, "move_right": KEY_D, "jump": KEY_K,
		"attack": KEY_J, "ability": KEY_U, "armor": KEY_I,
		"poison": KEY_O, "spawn_enemy": KEY_N, "restart": KEY_R,
		"restore_mp": KEY_M,
	}
	for action_name: String in bindings:
		if InputMap.has_action(action_name):
			continue
		InputMap.add_action(action_name)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action_name]
		InputMap.action_add_event(action_name, event)

func _add_wall(center: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = center
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	wall.add_child(collision)
	add_child(wall)

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "第一阶段 · 最小战斗闭环"
	title.position = Vector2(28, 18)
	title.add_theme_font_size_override("font_size", 26)
	layer.add_child(title)
	var help := Label.new()
	help.position = Vector2(28, 60)
	help.text = "A / D 移动    K 跳跃    J 普攻    U 冰龙波\n调试：I 霸体 3 秒    O 小怪中毒    M 回满 MP    N 重生小怪    R 重开"
	layer.add_child(help)
	_status = Label.new()
	_status.position = Vector2(28, 120)
	layer.add_child(_status)
	_update_hud()

func _update_hud() -> void:
	var enemy_hp := "已死亡（N 重生）"
	if is_instance_valid(enemy):
		enemy_hp = "%.0f" % enemy.combatant.health.current
	_status.text = "玩家 HP %.0f / %.0f    MP %.0f    冰龙波冷却 %.1f\n移动：%s    动作：%s    小猴子 HP：%s\n节点 %d    静态内存 %.2f MiB（仅当前样板）" % [
		player.combatant.health.current, player.combatant.health.maximum,
		player.abilities.mp, player.abilities.remaining_cooldown(&"ice_dragon_wave"),
		LocomotionState.State.keys()[player.locomotion.current],
		ActionState.State.keys()[player.action.current], enemy_hp,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
	]

func _draw() -> void:
	draw_rect(Rect2(0, 470, 960, 70), Color(0.14, 0.2, 0.28))
	draw_line(Vector2(0, 470), Vector2(960, 470), Color(0.3, 0.65, 0.8), 2.0)
