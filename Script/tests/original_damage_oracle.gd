extends RefCounted
# Test-only: arithmetic extracted from the original source, not the production calculator.
var level: int
var source_level: int
var rolls: Array
var is_miss := false
var is_crit := false
var IsDefeReduce := false
var DefeReduce := 0.0
var tqzbs := 0.0
var tszbsjm := 0.0
func roll(_low: float, _high: float) -> float:
	return rolls.pop_front()
func Level_suppression(Level):
	return level - Level > 0
func is_suppression_num(Level):
	return mini(2, level - Level)
func not_suppression_num(Level):
	return mini(2, Level - level)
func calculate(input: Dictionary, dodge: float, critical: float) -> int:
	level = int(input.target_level)
	source_level = int(input.source_level)
	rolls = [dodge, critical]
	is_miss = false
	is_crit = false
	return int(_hero(input) if input.hero_target else _monster(input))
func _monster(input: Dictionary):
	var Hurt = input.power
	var Miss = input.dodge - input.accuracy
	var Crit = input.critical - input.critical_resistance
	var Lucky = input.luck - input.toughness

	var LastDef = input.defense - input.penetration
	var LastMdef = LastDef
	var Level = source_level
	var HurtLx = ["physics", "magic", "real"][input.damage_type]
	if Miss <= 0:
		Miss = 0
	else:
		var miss_bl = abs(level - Level) * 0.04
		if miss_bl >= 0.9:
			miss_bl = 0.9
		if Level_suppression(Level):
			Miss = Miss * (1 + miss_bl)
		else:
			Miss = Miss * (1 - miss_bl)
	if Crit <= 0:
		Crit = 0
	else:
		var crit_bl = abs(level - Level) * 0.11
		if crit_bl >= 1:
			crit_bl = 1
		if Level_suppression(Level):
			Crit = Crit * (1 - crit_bl)
		else:
			Crit = Crit * (1 + crit_bl)
	if LastDef <= 0:
		LastDef = 0
	if LastMdef <= 0:
		LastMdef = 0
	if IsDefeReduce:
		LastDef *= 1 - DefeReduce
		LastMdef *= 1 - DefeReduce
	if Lucky <= 0 :
		Lucky = 0
	else:
		var lucky_bl = abs(level - Level) * 0.07
		if lucky_bl >= 0.7:
			lucky_bl = 0.7
		if Level_suppression(Level):
			Lucky = Lucky * (1 - lucky_bl)
		else:
			Lucky = Lucky * (1 + lucky_bl)
	var bl
	if Level_suppression(Level):
		Hurt = int(Hurt * (1 - is_suppression_num(Level) * 0.05))
	else:
		Hurt = int(Hurt * (1 + not_suppression_num(Level) * 0.05))
	Crit = snapped(Crit / float(Crit + 100),0.001)
	Miss = snapped(Miss / float(Miss + 70),0.001)
	if roll(0,1) <= Miss:
		is_miss = true
		return 0
	if roll(0,1) <= Crit:
		bl = 2 + snapped(Lucky / float(Lucky + 100),0.001) + tqzbs
		Hurt = Hurt * bl
		is_crit = true

	match HurtLx:
		"physics":
			var 减伤率 = snapped(LastDef / float(LastDef + 100),0.001)
			Hurt = int(Hurt * (1 - 减伤率))
		"magic":
			var 减伤率 = snapped(LastMdef / float(LastMdef + 100),0.001)
			Hurt = int(Hurt * (1 - 减伤率))
	return Hurt
func _hero(input: Dictionary):
	var Hurt = input.power
	var Miss = input.dodge - input.accuracy
	var Crit = input.critical - input.critical_resistance
	var Lucky = input.luck - input.toughness

	var last_def = input.defense - input.penetration
	var last_mdef = last_def
	var LevelInter = abs(source_level - level)
	var miss_bl = LevelInter * 0.03
	var crit_bl = LevelInter * 0.07
	var lucky_bl = LevelInter * 0.07
	var lx = ["physics", "magic", "real"][input.damage_type]
	if Miss <= 0:Miss = 0
	if Crit <= 0:Crit = 0
	if last_def <= 0:last_def = 0
	if last_mdef <= 0:last_mdef = 0
	if IsDefeReduce:
		last_def *= 1 - DefeReduce
		last_mdef *= 1 - DefeReduce
	if Lucky <= 0 :Lucky = 0
	if miss_bl >= 1:miss_bl = 1
	if crit_bl >= 1:crit_bl = 1	
	if lucky_bl >= 0.7:lucky_bl = 0.7
	if source_level - level < 0:
		Miss = Miss * (1 - miss_bl)
		Crit = Crit * (1 - crit_bl)
		Lucky = Lucky * (1 - lucky_bl)
		Hurt = int(Hurt * (1 - mini(5, abs(source_level - level)) * 0.05))
	else:
		Miss = Miss * (1 + miss_bl)
		Crit = Crit * (1 + crit_bl)
		Lucky = Lucky * (1 + lucky_bl)
		Hurt = int(Hurt * (1 + mini(5, abs(source_level - level)) * 0.05))
	var bl
	Crit = snapped(Crit / float(Crit + 100),0.001)
	Miss = snapped(Miss / float(Miss + 100),0.001)
	if roll(0,1) <= Miss:
		is_miss = true
		return 0
	if roll(0,1) <= Crit:
		bl = 2 + snapped(Lucky / float(Lucky + 50),0.001) - tszbsjm
		Hurt = Hurt * bl
		is_crit = true
	if lx == "physics":
		var 减伤率 = snapped(last_def / float(last_def + 250),0.001)
		Hurt = int(Hurt * (1 - 减伤率))
	elif lx == "magic":
		var 减伤率 = snapped(last_mdef / float(last_mdef + 250),0.001)
		Hurt = int(Hurt * (1 - 减伤率))
	return Hurt
