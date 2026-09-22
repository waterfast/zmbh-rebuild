class_name AbilityExecutor
extends RefCounted

static func execute(definition: AbilityDefinition, actor: Node2D, _request: SkillTriggerRequest = null) -> bool:
	if definition == null or actor == null or not actor.combatant.health.is_alive():
		return false
	for effect in definition.effects:
		if effect != null:
			effect.execute(actor, definition)
	# 兼容早期测试场技能资源；新内容只使用效果组合和按需场景路径。
	if definition.effects.is_empty() and definition.projectile_scene != null:
		var projectile = definition.projectile_scene.instantiate()
		projectile.payload = HitData.from_attacker(actor.combatant, actor.combatant.stats.value(&"attack") * definition.power_scale)
		projectile.speed = definition.projectile_speed
		projectile.direction = actor.facing
		projectile.lifetime = definition.projectile_lifetime
		projectile.single_target = true
		actor.get_parent().add_child(projectile)
		projectile.global_position = actor.global_position + Vector2(actor.facing * 32.0, -24.0)
		return true
	return not definition.effects.is_empty()
