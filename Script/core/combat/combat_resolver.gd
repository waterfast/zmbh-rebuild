class_name CombatResolver
extends RefCounted
## 普攻、飞行物和持续伤害共享入口，数值模块保留原作双方不同的计算路径。

static func resolve(hit: HitData, target: Combatant, random: RandomNumberGenerator = null) -> float:
	if hit == null or target == null or not target.health.is_alive() or hit.team == target.team:
		return 0.0
	if target.buffs.has_tag(&"invulnerable"):
		return 0.0
	var dodge_roll := random.randf() if random != null else randf()
	var critical_roll := random.randf() if random != null else randf()
	var result := LegacyDamageFormula.calculate(LegacyDamageFormula.from_hit(hit, target), dodge_roll, critical_roll)
	var requested := float(result.amount)
	if target.buffs.has_tag(&"indestructible") and requested >= target.health.current:
		return 0.0
	var amount := target.health.damage(requested)
	if amount <= 0.0:
		return 0.0
	var stun := 0.0 if target.buffs.has_tag(&"super_armor") else hit.hitstun
	target.damaged.emit(amount, stun)
	var attacker: Combatant = hit.source.get_ref() if hit.source != null else null
	if attacker != null:
		attacker.damage_dealt.emit(amount)
		if hit.triggers_passives:
			if hit.damage_type == HitData.DamageType.PHYSICAL:
				attacker.health.heal(int(amount * clampf(attacker.stats.value(&"lifesteal"), 0.0, 1.0)))
			attacker.passives.on_event(PassiveDefinition.Trigger.ON_HIT, target, amount)
	if hit.triggers_passives:
		target.passives.on_event(PassiveDefinition.Trigger.ON_DAMAGED, attacker, amount)
	if target.health.is_alive() and hit.buff != null:
		target.buffs.add(hit.buff, hit.source_id, hit)
	return amount

static func _roll(chance: float, random: RandomNumberGenerator) -> bool:
	if chance <= 0.0:
		return false
	if chance >= 1.0:
		return true
	return (random.randf() if random != null else randf()) < chance
