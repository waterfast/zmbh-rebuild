class_name IceDragonWaveAbility
extends AbilityDefinition

func _init() -> void:
	id = &"ice_dragon_wave"
	display_name = "冰龙波"
	description = "向前方释放冰龙冲击。"
	mp_cost = 25.0
	cooldown = 2.4
	effects = [ProjectileEffect.new()]
	effects[0].power_scale = 0.55
	effects[0].damage_type = HitData.DamageType.MAGIC
