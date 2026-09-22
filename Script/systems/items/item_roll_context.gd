class_name ItemRollContext
extends RefCounted
## 掉落、商店和初始装备都通过上下文传入独立 RNG；定义目录不保存任何实例随机值。

var rng: RandomNumberGenerator
var source: StringName
var level: int

func _init(
	roll_rng: RandomNumberGenerator = null,
	roll_source: StringName = &"drop",
	roll_level: int = 1
) -> void:
	rng = roll_rng if roll_rng != null else RandomNumberGenerator.new()
	if roll_rng == null:
		rng.randomize()
	source = roll_source
	level = maxi(1, roll_level)
