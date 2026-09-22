class_name HeavyStrikeAbility
extends AbilityDefinition

func _init() -> void:
	id = &"heavy_strike"
	display_name = "重斩"
	mp_cost = 8.0
	cooldown = 0.8
	effects = [MeleeEffect.new()]
	effects[0].power_scale = 1.35
	effects[0].size_scale = Vector2(1.35, 1.1)
