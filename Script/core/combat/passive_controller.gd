class_name PassiveController
extends RefCounted

var _owner: WeakRef
var _entries: Array[Dictionary] = []

func _init(owner: Combatant) -> void:
	_owner = weakref(owner)

func grant(definition: PassiveDefinition, source: StringName) -> void:
	if definition == null:
		return
	for entry in _entries:
		if entry.source == source and entry.definition.id == definition.id:
			entry.definition = definition
			return
	_entries.append({"definition": definition, "source": source, "remaining": 0.0})

func remove_source(source: StringName) -> void:
	for index in range(_entries.size() - 1, -1, -1):
		if _entries[index].source == source:
			_entries.remove_at(index)

func tick(delta: float) -> void:
	for entry in _entries:
		entry.remaining = maxf(0.0, entry.remaining - maxf(0.0, delta))

func on_event(trigger: PassiveDefinition.Trigger, other: Combatant, damage: float) -> void:
	var owner: Combatant = _owner.get_ref()
	if owner == null or not owner.health.is_alive():
		return
	for entry in _entries:
		var definition: PassiveDefinition = entry.definition
		if definition.trigger != trigger or entry.remaining > 0.0:
			continue
		if definition.chance <= 0.0 or (definition.chance < 1.0 and randf() >= definition.chance):
			continue
		entry.remaining = maxf(0.0, definition.cooldown)
		owner.health.heal(maxf(0.0, damage * definition.lifesteal + definition.heal_flat))
		var recipient: Combatant = owner if definition.buff_target_self else other
		if definition.buff != null and recipient != null and recipient.health.is_alive():
			var origin := StringName("passive:%d:%s:%s" % [owner.get_instance_id(), entry.source, definition.id])
			recipient.buffs.add(definition.buff, origin, HitData.from_attacker(owner, 0.0))
