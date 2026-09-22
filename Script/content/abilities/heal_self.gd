class_name HealSelfAbility
extends AbilityDefinition

func _init() -> void:
	id = &"heal_self"
	display_name = "天降甘露"
	mp_cost = 20.0
	cooldown = 5.0
	effects = [HealEffect.new()]
	effects[0].maximum_ratio = 0.18
	effects[0].missing_ratio = 0.20
