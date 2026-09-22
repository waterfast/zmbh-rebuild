class_name CombatResolver
extends RefCounted
## 普攻、飞行物和持续伤害共享此入口；不区分玩家和怪物。

static func resolve(hit: HitData, target: Combatant, random: RandomNumberGenerator = null) -> float:
	if hit == null or target == null or not target.health.is_alive() or hit.team == target.team:
		return 0.0
	if target.buffs.has_tag(&"invulnerable"):
		return 0.0
	var dodge := clampf(target.stats.value(&"dodge_chance") - hit.accuracy, 0.0, 1.0)
	if hit.can_dodge and _roll(dodge, random):
		return 0.0
	var defense := 0.0
	if not hit.ignores_defense and hit.damage_type != HitData.DamageType.TRUE:
		if hit.damage_type == HitData.DamageType.MAGIC:
			defense = maxf(0.0, target.stats.value(&"magic_defense") - hit.magic_penetration)
		else:
			defense = maxf(0.0, target.stats.value(&"defense") - hit.penetration)
	var power := maxf(0.0, hit.power)
	if _roll(clampf(hit.critical_chance - target.stats.value(&"critical_reduction"), 0.0, 1.0), random):
		power *= maxf(1.0, hit.critical_multiplier)
	var reduction := 0.0 if hit.damage_type == HitData.DamageType.TRUE else clampf(target.stats.value(&"damage_reduction"), 0.0, 1.0)
	var amount := target.health.damage(maxf(0.0, power - defense) * (1.0 - reduction))
	if amount <= 0.0:
		return 0.0
	var stun := 0.0 if target.buffs.has_tag(&"super_armor") else hit.hitstun * (1.0 - clampf(target.stats.value(&"toughness"), 0.0, 1.0))
	target.damaged.emit(amount, stun)
	var attacker: Combatant = hit.source.get_ref() if hit.source != null else null
	if attacker != null:
		attacker.damage_dealt.emit(amount)
		if hit.triggers_passives:
			attacker.health.heal(amount * clampf(attacker.stats.value(&"lifesteal"), 0.0, 1.0))
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
