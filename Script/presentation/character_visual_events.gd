class_name CharacterVisualEvents
extends RefCounted
## 旧动作方法轨道中的纯视觉事件。只生成图像，不修改战斗状态。

const EVENT_NAMES := {
	"AddTJGL": true,
	"AddMYHC": true,
	"AddJGZ": true,
	"AddJHSJ": true,
	"AddSD": true,
	"AddZZNH": true,
	"AddSMb_1": true,
}

static func for_action(character: int, animation: StringName) -> Array[Dictionary]:
	var metadata := CharacterActionCatalog.metadata(character, animation)
	var result: Array[Dictionary] = []
	for event_name: String in metadata.get("events", {}):
		if not EVENT_NAMES.has(event_name):
			continue
		for timestamp: Variant in metadata.events[event_name]:
			result.append({"time": float(timestamp), "name": event_name})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.time) < float(b.time))
	return result

static func trigger(actor: CombatActor, event_name: String) -> void:
	if not is_instance_valid(actor):
		return
	var facing := actor.facing
	match event_name:
		"AddTJGL":
			_spawn_role_effect(actor, &"tjgl", Vector2(0, -35), false, true)
		"AddMYHC":
			_spawn_role_effect(actor, &"myhc", Vector2(0, -30))
		"AddJGZ":
			_spawn_role_effect(actor, &"jgz", Vector2(210 * facing, 0), false, false, true)
		"AddJHSJ":
			_spawn_role_effect(actor, &"jhsj", Vector2(20 * facing, -15), facing > 0)
		"AddSD":
			_spawn_role_effect(actor, &"sd", Vector2.ZERO)
		"AddZZNH":
			_spawn_role_effect(actor, &"zznh", Vector2(30 * facing, -30))
		"AddSMb_1":
			if is_instance_valid(actor.get_parent()):
				var effect := load("res://Scene/Effects/SmbEffect.tscn").instantiate() as SmbEffectView
				effect.effect_flip = facing < 0
				actor.get_parent().add_child(effect)
				effect.global_position = actor.global_position + Vector2(100 * facing, 25)

static func _spawn_role_effect(actor: CombatActor, animation: StringName, offset: Vector2,
		flip: bool = false, behind: bool = false, world_space: bool = false) -> void:
	var effect := load("res://Scene/Effects/RoleSpecialEffect.tscn").instantiate() as RoleSpecialEffectView
	effect.effect_name = animation
	effect.effect_flip = flip
	effect.show_behind_parent = behind
	if world_space:
		if not is_instance_valid(actor.get_parent()):
			return
		actor.get_parent().add_child(effect)
		effect.global_position = actor.global_position + offset
	else:
		actor.add_child(effect)
		effect.position = offset
