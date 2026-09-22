class_name QuickDashAbility
extends AbilityDefinition

func _init() -> void:
	id = &"quick_dash"
	display_name = "烈焰闪"
	mp_cost = 12.0
	cooldown = 1.4
	effects = [DashEffect.new()]
