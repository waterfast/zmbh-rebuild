class_name LegacyDamageFormula
extends RefCounted
## 纯数值函数，对照 BaseMonster.get_Role_last_hurt / BaseHero.get_Monster_last_hurt。
## 输入暴击、闪避、命中、韧性均为旧版原始点数，绝不是概率。
static func calculate(input: Dictionary, dodge_roll: float, critical_roll: float) -> Dictionary:
	var hero_target := bool(input.get("hero_target", false))
	var source_level := int(input.get("source_level", 1))
	var target_level := int(input.get("target_level", 1))
	var difference := absf(source_level - target_level)
	var miss := maxf(0, float(input.get("dodge", 0)) - float(input.get("accuracy", 0)))
	var critical := maxf(0, float(input.get("critical", 0)) - float(input.get("critical_resistance", 0)))
	var luck := maxf(0, float(input.get("luck", 0)) - float(input.get("toughness", 0)))
	var power := maxf(0, float(input.get("power", 0))) * float(input.get("weakness_multiplier", 1))
	if hero_target:
		# 保留原作玩家受击路径的方向，包括其不对称的闪避等级修正。
		var sign_value := -1.0 if source_level < target_level else 1.0
		miss *= 1 + sign_value * minf(1, difference * 0.03)
		critical *= 1 + sign_value * minf(1, difference * 0.07)
		luck *= 1 + sign_value * minf(0.7, difference * 0.07)
		power = int(power * (1 + sign_value * minf(5, difference) * 0.05))
	else:
		var suppressed := target_level > source_level
		miss *= 1 + minf(0.9, difference * 0.04) * (1 if suppressed else -1)
		critical *= 1 + minf(1, difference * 0.11) * (-1 if suppressed else 1)
		luck *= 1 + minf(0.7, difference * 0.07) * (-1 if suppressed else 1)
		power = int(power * (1 + minf(2, difference) * 0.05 * (-1 if suppressed else 1)))
	var miss_probability := snappedf(miss / (miss + (100.0 if hero_target else 70.0)), 0.001)
	var critical_probability := snappedf(critical / (critical + 100.0), 0.001)
	if bool(input.get("can_dodge", true)) and dodge_roll <= miss_probability:
		return {"amount": 0, "missed": true, "critical": false}
	var is_critical := bool(input.get("can_crit", true)) and critical_roll <= critical_probability
	if is_critical:
		var multiplier := 2 + snappedf(luck / (luck + (50.0 if hero_target else 100.0)), 0.001)
		multiplier += float(input.get("critical_bonus", 0)) - float(input.get("critical_damage_reduction", 0))
		power *= multiplier
	var kind := int(input.get("damage_type", HitData.DamageType.PHYSICAL))
	if kind != HitData.DamageType.TRUE and not bool(input.get("ignores_defense", false)):
		var defense := maxf(0, float(input.get("defense", 0)) - float(input.get("penetration", 0)))
		defense *= 1 - clampf(float(input.get("defense_reduction", 0)), 0, 1)
		var ratio := snappedf(defense / (defense + (250.0 if hero_target else 100.0)), 0.001)
		power = int(power * (1 - ratio))
	# 原调用点最后进入 int 参数的扣血函数；先减伤截断，再结算外部增减伤。
	power *= float(input.get("final_multiplier", 1))
	return {"amount": maxi(0, int(power)), "missed": false, "critical": is_critical}

static func from_hit(hit: HitData, target: Combatant) -> Dictionary:
	var magic := hit.damage_type == HitData.DamageType.MAGIC
	return {
		"hero_target": target.team == 1,
		"source_level": hit.source_level, "target_level": int(target.stats.value(&"level")),
		"power": hit.power, "damage_type": hit.damage_type,
		"critical": hit.critical_chance * 100.0, "critical_resistance": target.stats.value(&"critical_reduction") * 100.0,
		"dodge": target.stats.value(&"dodge_chance") * 100.0, "accuracy": hit.accuracy * 100.0,
		"luck": hit.luck, "toughness": target.stats.value(&"toughness") * 100.0,
		"defense": target.stats.value(&"magic_defense" if magic else &"defense"),
		"penetration": hit.magic_penetration if magic else hit.penetration,
		"can_dodge": hit.can_dodge, "can_crit": hit.can_crit, "ignores_defense": hit.ignores_defense,
		"weakness_multiplier": hit.weakness_multiplier, "critical_bonus": hit.critical_bonus,
		"critical_damage_reduction": target.stats.value(&"critical_damage_reduction"),
		"defense_reduction": target.stats.value(&"defense_reduction"),
		"final_multiplier": hit.final_multiplier * (1.0 - clampf(target.stats.value(&"damage_reduction"), 0, 1)) * target.stats.value(&"damage_taken_multiplier"),
	}
