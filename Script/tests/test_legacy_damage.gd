extends SceneTree
const Oracle = preload("res://Script/tests/original_damage_oracle.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var oracle = Oracle.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260922
	for hero_target in [false, true]:
		for kind in range(3):
			for index in 400:
				var input := {
					"hero_target":hero_target,"damage_type":kind,
					"source_level":rng.randi_range(1,80),"target_level":rng.randi_range(1,80),
					"power":rng.randf_range(0,10000),"defense":rng.randf_range(0,2000),"penetration":rng.randf_range(0,2000),
					"dodge":rng.randf_range(0,150),"accuracy":rng.randf_range(0,150),
					"critical":rng.randf_range(0,200),"critical_resistance":rng.randf_range(0,200),
					"luck":rng.randf_range(0,300),"toughness":rng.randf_range(0,300),
				}
				var miss_roll := rng.randf()
				var crit_roll := rng.randf()
				var expected: int = oracle.calculate(input, miss_roll, crit_roll)
				var actual := LegacyDamageFormula.calculate(input, miss_roll, crit_roll)
				check(actual.amount == expected and actual.missed == oracle.is_miss and actual.critical == oracle.is_crit, "原公式差异 %s：expected=%d actual=%s" % [input,expected,actual])
	var input := {"hero_target":false,"power":100,"defense":100,"damage_type":0}
	check(LegacyDamageFormula.calculate(input,1,1).amount == 50, "玩家打怪100防御减伤50%")
	input.hero_target = true
	check(LegacyDamageFormula.calculate(input,1,1).amount == 71, "怪物打玩家100防御按250分母并取整")
	var stats := OriginalCombatCatalog.monster(1)
	check(stats.level == 5 and stats.defense == 50 and stats.magic_defense == 80 and stats.max_hp == 60, "小猴子数值来自原项目")
	var row := OriginalCombatCatalog.hit(1, &"slz")
	check(is_equal_approx(OriginalCombatCatalog.evaluate(row.power,{"attack":100,"skill_level":2}),274), "已学升龙斩原倍率2.74")
	print("LEGACY DAMAGE PARITY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
