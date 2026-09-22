class_name StageEncounter
extends Node
## 波次保留数据顺序，限制同时存活数；不预生成未到达区域的怪物。

signal enemy_defeated(monster_id: int, position: Vector2)
signal stage_cleared(stage: int)
signal completed

var world: WorldSession
var player: CombatActor
var stage_index: int = 0
var finished: bool = false
var _next_spawn: int = 0
var _living: int = 0
var _wave_active: bool = false
var _next_wave: bool = false
var _spawn_elapsed: float = 0.0
var _enemies: Array[CombatActor] = []

func setup(session: WorldSession, target: CombatActor) -> void:
	world = session
	player = target
	for wave: Dictionary in world.definition.waves:
		world.set_gate_open(int(wave.stage), false)
	_start_wave()

func _physics_process(delta: float) -> void:
	if finished or not is_instance_valid(player) or not player.combatant.health.is_alive():
		return
	if _next_wave:
		var positions: PackedVector2Array = world.definition.waves[stage_index].positions
		if positions.is_empty() or player.position.x >= positions[0].x - 600.0:
			_start_wave()
	_spawn_elapsed += delta
	if _wave_active and _spawn_elapsed >= 0.35 and _living < world.definition.maximum_active_enemies:
		_spawn_elapsed = 0.0
		_spawn_one()
	if _wave_active:
		for enemy: CombatActor in _enemies:
			if is_instance_valid(enemy) and enemy.position.y > 1400.0 and enemy.combatant.health.is_alive():
				enemy.combatant.health.damage(enemy.combatant.health.maximum)

func _start_wave() -> void:
	_next_wave = false
	if stage_index >= world.definition.waves.size():
		finished = true
		completed.emit()
		return
	_wave_active = true
	_next_spawn = 0
	_spawn_one()

func _spawn_one() -> void:
	var wave: Dictionary = world.definition.waves[stage_index]
	var ids: PackedInt32Array = wave.monster_ids
	if _next_spawn >= ids.size():
		return
	var monster_id := ids[_next_spawn]
	var position: Vector2 = wave.positions[_next_spawn]
	_next_spawn += 1
	var enemy := load("res://actors/enemy.tscn").instantiate() as CombatActor
	var stats := StatDefinition.new()
	stats.max_hp = 60.0 + float(monster_id - 1) * 24.0
	stats.attack = 10.0 + float(monster_id - 1) * 2.0
	stats.defense = 2.0 + float(monster_id - 1)
	stats.max_mp = 0.0
	stats.move_speed = 80.0 + minf(55.0, monster_id * 4.0)
	enemy.definition = stats
	enemy.debug_draw = false
	world.add_actor(enemy, position)
	var view := enemy.get_node_or_null("ActorView") as ActorView
	if view != null:
		var skin_id := &"monkey" if monster_id == 1 else StringName("monster_%d" % monster_id)
		view.set_skin(skin_id)
	enemy.get_node("EnemyAI").target = player
	enemy.combatant.health.died.connect(_on_enemy_died.bind(enemy, monster_id), CONNECT_ONE_SHOT)
	_living += 1
	_enemies.append(enemy)

func _on_enemy_died(enemy: CombatActor, monster_id: int) -> void:
	_living -= 1
	_enemies.erase(enemy)
	enemy_defeated.emit(monster_id, enemy.position)
	var wave: Dictionary = world.definition.waves[stage_index]
	if _living == 0 and _next_spawn >= wave.monster_ids.size():
		_wave_active = false
		world.set_gate_open(int(wave.stage), true)
		stage_cleared.emit(int(wave.stage))
		stage_index += 1
		if stage_index >= world.definition.waves.size():
			finished = true
			completed.emit()
		else:
			_next_wave = true

func remaining_enemies() -> int:
	if finished or stage_index >= world.definition.waves.size():
		return 0
	return _living + world.definition.waves[stage_index].monster_ids.size() - _next_spawn
