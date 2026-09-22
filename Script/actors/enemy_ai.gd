extends ActorController
## 目标由关卡注入，不扫描全树，也不依赖 Global.player。

var target: CombatActor
var sight_range: float = 420.0
var attack_range: float = 48.0

func _physics_process(_delta: float) -> void:
	if not enabled:
		return
	command.clear()
	if not is_instance_valid(target) or not target.combatant.health.is_alive():
		submit()
		return
	if not actor.combatant.health.is_alive():
		submit()
		return
	var offset := target.global_position - actor.global_position
	if offset.length_squared() > sight_range * sight_range:
		submit()
		return
	if absf(offset.x) > 1.0 and actor.action.current == ActionState.State.FREE:
		actor.facing = signf(offset.x)
	if absf(offset.x) <= attack_range and absf(offset.y) < 50.0:
		command.attack = true
	else:
		command.movement = signf(offset.x)
	submit()
