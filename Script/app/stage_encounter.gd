class_name StageEncounter
extends Node
## 波次保留数据顺序，限制同时存活数；不预生成未到达区域的怪物。

signal enemy_landed_hit
signal enemy_defeated(monster_id: int, position: Vector2)
signal stage_cleared(stage: int)
signal completed

var received_hits := 0
var total_damage_received: float = 0.0
var total_damage_dealt: float = 0.0
var landed_hits: int = 0
## 关卡结算用到的连击统计：玩家连续命中不被打断的最多次数。
var maximum_combo := 0
var current_combo := 0
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
	player.combatant.damaged.connect(_count_received_hit)
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
	var stats := OriginalCombatCatalog.monster(monster_id, {
		"hero_level": player.combatant.stats.value(&"level"),
		"max_hp": player.combatant.health.maximum,
		"attack": player.combatant.stats.value(&"attack"),
		"hero_defense": player.combatant.stats.value(&"defense"),
		"hero_magic_defense": player.combatant.stats.value(&"magic_defense"),
		"received_hits": received_hits,
	})
	enemy.definition = stats
	enemy.debug_draw = false
	world.add_actor(enemy, position)
	var view := enemy.get_node_or_null("ActorView") as ActorView
	if view != null:
		var skin_id := &"monkey" if monster_id == 1 else StringName("monster_%d" % monster_id)
		view.set_skin(skin_id)
	enemy.get_node("EnemyAI").target = player
	enemy.combatant.health.died.connect(_on_enemy_died.bind(enemy, monster_id), CONNECT_ONE_SHOT)
	enemy.combatant.damaged.connect(_count_landed_hit)
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
			# 留出最后一只怪的死亡动画和粒子播放时间，再显示结算。
			if enemy.despawn_on_death:
				enemy.despawning.connect(_on_final_enemy_despawning, CONNECT_ONE_SHOT)
			else:
				_complete_level()
		else:
			_next_wave = true

func _on_final_enemy_despawning() -> void:
	get_tree().create_timer(0.5, false).timeout.connect(_complete_level, CONNECT_ONE_SHOT)

func _complete_level() -> void:
	if finished:
		return
	finished = true
	completed.emit()

func remaining_enemies() -> int:
	if finished or stage_index >= world.definition.waves.size():
		return 0
	return _living + world.definition.waves[stage_index].monster_ids.size() - _next_spawn

func _count_received_hit(amount: float, _stun: float) -> void:
	received_hits += 1
	total_damage_received += amount
	current_combo = 0

func _count_landed_hit(amount: float, _stun: float) -> void:
	landed_hits += 1
	current_combo += 1
	total_damage_dealt += amount
	maximum_combo = maxi(maximum_combo, current_combo)
	enemy_landed_hit.emit()
