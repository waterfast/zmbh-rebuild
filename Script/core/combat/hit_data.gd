class_name HitData
extends RefCounted
## 攻击生成时快照；弱引用避免飞行物/Buff 延长攻击者生命周期。

var source: WeakRef
var source_id: StringName
var team: int
var source_level: int = 1
var luck: float = 0.0
var critical_bonus: float = 0.0
var weakness_multiplier: float = 1.0
var final_multiplier: float = 1.0
var can_crit: bool = true
var power: float
var hitstun: float = 0.2
var ignores_defense: bool = false
var buff: BuffDefinition
enum DamageType { PHYSICAL, MAGIC, TRUE }
var damage_type: DamageType = DamageType.PHYSICAL
var critical_chance: float = 0.0
var critical_multiplier: float = 1.5
var accuracy: float = 0.0
var penetration: float = 0.0
var magic_penetration: float = 0.0
var can_dodge: bool = true
var triggers_passives: bool = true

static func from_attacker(attacker: Combatant, amount: float) -> HitData:
	var hit := HitData.new()
	hit.source = weakref(attacker)
	hit.source_id = StringName("combatant:%d" % attacker.get_instance_id())
	hit.team = attacker.team
	hit.power = amount
	hit.source_level = int(attacker.stats.value(&"level"))
	hit.luck = attacker.stats.value(&"luck")
	hit.critical_bonus = attacker.stats.value(&"critical_damage_bonus")
	hit.weakness_multiplier = attacker.stats.value(&"weakness_multiplier")
	hit.final_multiplier = attacker.stats.value(&"damage_dealt_multiplier")
	hit.critical_chance = attacker.stats.value(&"critical_chance")
	hit.critical_multiplier = attacker.stats.value(&"critical_multiplier")
	hit.accuracy = attacker.stats.value(&"accuracy")
	hit.penetration = attacker.stats.value(&"armor_penetration")
	hit.magic_penetration = attacker.stats.value(&"magic_penetration")
	return hit
