class_name HolyScriptureBurst
extends Node2D
## 原九环圣经在前方目标位置连续播放三次，每次使用旧命中帧。

const BULLET := preload("res://Scene/Combat/Spells/Hero1Bullet.tscn")
const PULSE_INTERVAL := 1.19

var target: WeakRef
var payload: HitData
var _elapsed := 0.0
var _next_pulse := 0

func _ready() -> void:
	_spawn_pulse()

func _physics_process(delta: float) -> void:
	_elapsed += delta
	while _next_pulse < 3 and _elapsed >= _next_pulse * PULSE_INTERVAL:
		_spawn_pulse()
	if _next_pulse >= 3 and _elapsed >= 2 * PULSE_INTERVAL + 0.64:
		queue_free()

func _spawn_pulse() -> void:
	var victim: CombatActor = target.get_ref() if target != null else null
	if not is_instance_valid(victim) or not victim.combatant.health.is_alive():
		_next_pulse = 3
		queue_free()
		return
	var bullet := BULLET.instantiate() as Hero1Bullet
	bullet.payload = payload
	get_parent().add_child(bullet)
	bullet.global_position = victim.global_position
	_next_pulse += 1
