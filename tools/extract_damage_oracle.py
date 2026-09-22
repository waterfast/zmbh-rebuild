"""Generate a test-only oracle from original arithmetic, retaining the source statements."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
monster=(ROOT/'Script/Base/BaseMonster.gd').read_text(encoding='utf-8-sig')
hero=(ROOT/'Script/Base/BaseHero.gd').read_text(encoding='utf-8-sig')
monster=monster[monster.index('func get_Role_last_hurt'):monster.index('func reduce_hp(value: int):')]
monster=monster[monster.index('\tif Miss <= 0:'):monster.index('\tif IsIndestructible:')]
hero=hero[hero.index('func get_Monster_last_hurt'):hero.index('func Level_suppression')]
hero=hero[hero.index('\tif Miss <= 0:'):hero.index('\tif IsIndestructible:')]
head='''extends RefCounted
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
'''
common='''
	var Hurt = input.power
	var Miss = input.dodge - input.accuracy
	var Crit = input.critical - input.critical_resistance
	var Lucky = input.luck - input.toughness
'''
monster_head='''func _monster(input: Dictionary):'''+common+'''
	var LastDef = input.defense - input.penetration
	var LastMdef = LastDef
	var Level = source_level
	var HurtLx = ["physics", "magic", "real"][input.damage_type]
'''
hero_head='''func _hero(input: Dictionary):'''+common+'''
	var last_def = input.defense - input.penetration
	var last_mdef = last_def
	var LevelInter = abs(source_level - level)
	var miss_bl = LevelInter * 0.03
	var crit_bl = LevelInter * 0.07
	var lucky_bl = LevelInter * 0.07
	var lx = ["physics", "magic", "real"][input.damage_type]
'''
def clean(s):
 s='\n'.join(line for line in s.splitlines() if 'Global.' not in line and 'randomize()' not in line)+'\n'
 return s.replace('randf_range(0,1)','roll(0,1)')
hero=clean(hero).replace('\telif lx == "real":\n','').replace('target_boss.level - RoleProp.baseroleprop.Level','source_level - level').replace('is_suppression_num(target_boss)','mini(5, abs(source_level - level))')
monster=clean(monster)
(ROOT/'refactor/Script/tests/original_damage_oracle.gd').write_text(head+monster_head+monster+'\treturn Hurt\n'+hero_head+hero+'\treturn Hurt\n',encoding='utf-8')
