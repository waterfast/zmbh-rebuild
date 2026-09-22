class_name AbilityController
extends RefCounted

signal cast(definition: AbilityDefinition)
signal triggered(request: SkillTriggerRequest, definition: AbilityDefinition)
signal mana_changed(current: float, maximum: float)
signal grants_changed

var mp: float
var maximum_mp: float
var _grants: Dictionary = {}
var _cooldowns: Dictionary = {}
var _cooldown_ids: Array[StringName] = []
var _stats: ActorStats

func bind_stats(stats: ActorStats) -> void:
	if _stats != null and _stats.changed.is_connected(_sync_maximum):
		_stats.changed.disconnect(_sync_maximum)
	_stats = stats
	_stats.changed.connect(_sync_maximum)
	_sync_maximum()

func _sync_maximum() -> void:
	maximum_mp = _stats.value(&"max_mp")
	mp = minf(mp, maximum_mp)
	mana_changed.emit(mp, maximum_mp)

func _init(max_mp: float) -> void:
	maximum_mp = maxf(0.0, max_mp)
	mp = maximum_mp

func grant(definition: AbilityDefinition, source: StringName, category: StringName = &"", source_kind: StringName = &"") -> void:
	if definition == null or definition.id.is_empty():
		return
	if not _grants.has(definition.id):
		_grants[definition.id] = {}
	_grants[definition.id][source] = AbilityGrant.new(definition, source, category, source_kind)
	grants_changed.emit()

func grant_record(grant_record: AbilityGrant) -> void:
	if grant_record == null:
		return
	grant(grant_record.definition, grant_record.source_id, grant_record.category, grant_record.source_kind)

func remove_source(source: StringName) -> void:
	var changed := false
	for id: StringName in _grants.keys():
		changed = _grants[id].has(source) or changed
		_grants[id].erase(source)
		if _grants[id].is_empty():
			_grants.erase(id)
	# 冷却保留到到期，避免卸装再装备绕过冷却。
	if changed:
		grants_changed.emit()

func has_ability(id: StringName) -> bool:
	return _grants.has(id)

func has_category(id: StringName, category: StringName) -> bool:
	return _find_grant(id, category, &"") != null

func remaining_cooldown(id: StringName) -> float:
	return _cooldowns.get(id, 0.0)

func try_trigger(request: SkillTriggerRequest) -> bool:
	if request == null or request.ability_id.is_empty() or remaining_cooldown(request.ability_id) > 0.0:
		return false
	var grant_record := _find_grant(request.ability_id, request.category, request.source_id)
	if grant_record == null:
		return false
	var definition: AbilityDefinition = grant_record.definition
	if definition.migration_status == "metadata_only":
		return false
	var cost := maxf(0.0, definition.mp_cost)
	if request.action == null or mp < cost or not request.action.try_start(ActionState.State.SKILL, maxf(0.0, definition.cast_duration)):
		return false
	mp -= cost
	if definition.cooldown > 0.0:
		_cooldowns[request.ability_id] = definition.cooldown
		_cooldown_ids.append(request.ability_id)
	mana_changed.emit(mp, maximum_mp)
	triggered.emit(request, definition)
	cast.emit(definition)
	return true

func try_cast(id: StringName, action: ActionState) -> bool:
	var request := SkillTriggerRequest.new(id, &"", &"", action)
	return try_trigger(request)

func get_definition(id: StringName) -> AbilityDefinition:
	var grant_record := _find_grant(id, &"", &"")
	return grant_record.definition if grant_record != null else null

func get_definition_for(id: StringName, category: StringName = &"", source: StringName = &"") -> AbilityDefinition:
	var grant_record := _find_grant(id, category, source)
	return grant_record.definition if grant_record != null else null

func get_grant(id: StringName, category: StringName = &"", source: StringName = &"") -> AbilityGrant:
	return _find_grant(id, category, source)

func grants() -> Array[AbilityGrant]:
	var result: Array[AbilityGrant] = []
	for by_source: Dictionary in _grants.values():
		for grant_record: AbilityGrant in by_source.values():
			result.append(grant_record)
	return result

func sources_for(id: StringName) -> Array[StringName]:
	if not _grants.has(id):
		return []
	return _grants[id].keys()

func _find_grant(id: StringName, category: StringName, source: StringName) -> AbilityGrant:
	if not _grants.has(id):
		return null
	var by_source: Dictionary = _grants[id]
	if not source.is_empty() and by_source.has(source):
		var exact: AbilityGrant = by_source[source]
		if category.is_empty() or exact.category == category:
			return exact
	for candidate: AbilityGrant in by_source.values():
		if category.is_empty() or candidate.category == category:
			return candidate
	return null

func granted_ids() -> Array:
	return _grants.keys()

func tick(delta: float) -> void:
	delta = maxf(0.0, delta)
	for index in range(_cooldown_ids.size() - 1, -1, -1):
		var id := _cooldown_ids[index]
		_cooldowns[id] = maxf(0.0, _cooldowns[id] - delta)
		if _cooldowns[id] == 0.0:
			_cooldowns.erase(id)
			_cooldown_ids.remove_at(index)
	if _stats != null and mp < maximum_mp:
		restore_mp(_stats.value(&"mp_regen") * delta)

func restore_mp(amount: float) -> void:
	if amount <= 0.0:
		return
	mp = clampf(mp + amount, 0.0, maximum_mp)
	mana_changed.emit(mp, maximum_mp)
