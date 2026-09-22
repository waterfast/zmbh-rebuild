class_name BuffContainer
extends RefCounted
## 小规模 Buff 用数值计时，避免每层 Buff 创建 Timer/Node。

var _active: Array[BuffInstance] = []
var _pending_hits: Array[HitData] = []
var _stats: ActorStats

func _init(stats: ActorStats = null) -> void:
	_stats = stats

func add(definition: BuffDefinition, source: StringName, hit: HitData = null) -> void:
	if definition == null or definition.duration <= 0.0:
		return
	# 同 ID 同来源刷新持续时间，不叠层；不同来源可独立移除。
	for instance in _active:
		if instance.definition.id == definition.id and instance.source == source:
			instance.remaining = definition.duration
			instance.hit = hit
			return
	var instance := BuffInstance.new(definition, source, hit)
	_active.append(instance)
	if _stats != null:
		for stat: String in definition.flat_modifiers:
			_stats.set_modifier(instance.modifier_source, StringName(stat), float(definition.flat_modifiers[stat]), float(definition.percent_modifiers.get(stat, 0.0)))
		for stat: String in definition.percent_modifiers:
			if not definition.flat_modifiers.has(stat):
				_stats.set_modifier(instance.modifier_source, StringName(stat), 0.0, float(definition.percent_modifiers[stat]))

func _remove_at(index: int) -> void:
	var instance := _active[index]
	_active.remove_at(index)
	if _stats != null:
		_stats.remove_source(instance.modifier_source)

func remove_source(source: StringName) -> void:
	for index in range(_active.size() - 1, -1, -1):
		if _active[index].source == source:
			_remove_at(index)

func has_tag(tag: StringName) -> bool:
	for instance in _active:
		if instance.definition.tag == tag:
			return true
	return false

func clear() -> void:
	while not _active.is_empty():
		_remove_at(_active.size() - 1)

func tick(delta: float, target: Combatant) -> void:
	if delta <= 0.0 or not target.health.is_alive():
		return
	# 先收集伤害再结算，防止死亡回调清空集合时破坏遍历。
	_pending_hits.clear()
	var pending_heal := 0.0
	for index in range(_active.size() - 1, -1, -1):
		var instance := _active[index]
		var definition := instance.definition
		instance.elapsed += minf(delta, instance.remaining)
		instance.remaining -= delta
		if definition.tick_interval > 0.0:
			while instance.elapsed + 0.00001 >= definition.tick_interval:
				instance.elapsed -= definition.tick_interval
				pending_heal += definition.tick_heal + definition.tick_heal_maximum_ratio * target.health.maximum
				if instance.hit == null or definition.tick_damage <= 0.0:
					continue
				var pulse := HitData.new()
				pulse.source = instance.hit.source
				pulse.source_id = instance.hit.source_id
				pulse.team = instance.hit.team
				pulse.power = definition.tick_damage
				pulse.hitstun = 0.0
				pulse.ignores_defense = true
				pulse.can_dodge = false
				pulse.triggers_passives = false
				_pending_hits.append(pulse)
		if instance.remaining <= 0.00001:
			_remove_at(index)
	for hit in _pending_hits:
		CombatResolver.resolve(hit, target)
	_pending_hits.clear()
	target.health.heal(pending_heal)
