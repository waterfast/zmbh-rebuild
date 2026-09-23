class_name HolyScriptureEffect
extends AbilityEffect
## 只依赖同一关卡的 Actor 集合，目标选择和结算不调用旧全局对象。

func execute(actor: Node2D, definition: AbilityDefinition) -> void:
	if not actor is CombatActor or actor.get_parent() == null:
		return
	var chosen: CombatActor
	var distance := INF
	for candidate: Node in actor.get_parent().get_children():
		var enemy := candidate as CombatActor
		if enemy == null or enemy.team == actor.team or not enemy.combatant.health.is_alive():
			continue
		var delta: Vector2 = enemy.global_position - actor.global_position
		if delta.x * actor.facing < 0.0 or absf(delta.x) > 2000.0 or absf(delta.x) >= distance:
			continue
		chosen = enemy
		distance = absf(delta.x)
	if chosen == null:
		return
	var burst := HolyScriptureBurst.new()
	burst.target = weakref(chosen)
	burst.payload = OriginalCombatCatalog.payload(actor, definition, 1.0)
	actor.get_parent().add_child(burst)
