class_name SelfBuffEffect
extends AbilityEffect

@export var buff: BuffDefinition

func execute(actor: Node2D, definition: AbilityDefinition) -> void:
	if buff != null:
		actor.combatant.buffs.add(buff, definition.id, HitData.from_attacker(actor.combatant, 0.0))
