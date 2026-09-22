class_name Combatant
extends RefCounted

signal damaged(amount: float, hitstun: float)
signal damage_dealt(amount: float)

var team: int
var stats: ActorStats
var health: ActorHealth
var buffs: BuffContainer
var passives: PassiveController

func _init(definition: StatDefinition, faction: int) -> void:
	team = faction
	stats = ActorStats.new(definition)
	health = ActorHealth.new(stats.value(&"max_hp"))
	buffs = BuffContainer.new(stats)
	passives = PassiveController.new(self)
	stats.changed.connect(_sync_health_maximum)
	health.died.connect(_on_died)

func _sync_health_maximum() -> void:
	health.set_maximum(stats.value(&"max_hp"))

func _on_died() -> void:
	buffs.clear()

func tick(delta: float) -> void:
	if not health.is_alive():
		return
	passives.tick(delta)
	buffs.tick(delta, self)
	if health.current < health.maximum:
		health.heal(stats.value(&"hp_regen") * maxf(0.0, delta))
