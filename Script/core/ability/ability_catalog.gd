class_name AbilityCatalog
extends RefCounted
## 索引只保留路径；定义使用弱缓存，装备/角色释放技能后即可回收。

var _index: Dictionary = {}
var _cache: Dictionary = {}

func _init(index_path: String = "res://content/abilities/index.json") -> void:
	if FileAccess.file_exists(index_path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(index_path))
		if data is Dictionary:
			_index = data

func ids() -> Array:
	return _index.keys()

func resolve(id: StringName) -> AbilityDefinition:
	if _cache.has(id):
		var cached: AbilityDefinition = _cache[id].get_ref()
		if cached != null:
			return cached
	if not _index.has(String(id)):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_index[String(id)]))
	if not data is Dictionary:
		return null
	var definition := AbilityDefinition.new()
	definition.id = id
	definition.category = StringName(data.get("category", "character"))
	definition.source_kind = StringName(data.get("source_kind", definition.category))
	definition.legacy_id = StringName(data.get("legacy_id", ""))
	definition.display_name = data.get("display_name", "")
	definition.description = data.get("description", "")
	definition.character_id = int(data.get("character_id", 0))
	definition.slot = int(data.get("slot", 0))
	definition.passive = bool(data.get("passive", false))
	definition.mp_cost = float(data.get("mp_cost", 0.0))
	definition.cooldown = float(data.get("cooldown", 0.0))
	definition.cast_duration = float(data.get("cast_duration", 0.3))
	definition.animation = StringName(data.get("animation", data.get("legacy_id", id)))
	definition.release_delay = float(data.get("release_delay", 0.0))
	definition.migration_status = data.get("migration_status", "metadata_only")
	for effect_data: Dictionary in data.get("effects", []):
		var effect := _effect_from_data(effect_data)
		if effect != null:
			definition.effects.append(effect)
	_cache[id] = weakref(definition)
	return definition

func runtime_resolve(id: StringName) -> AbilityDefinition:
	var source := resolve(id)
	if source == null:
		return null
	if not source.effects.is_empty():
		return source
	var runtime := source.duplicate(true) as AbilityDefinition
	runtime.migration_status = "implemented"
	runtime.effects = _default_effects(runtime)
	return runtime

func for_character(character_id: int, include_passive: bool = true) -> Array[AbilityDefinition]:
	var result: Array[AbilityDefinition] = []
	for id: String in _index:
		var definition := runtime_resolve(StringName(id))
		if definition == null or definition.character_id != character_id:
			continue
		if not include_passive and definition.passive:
			continue
		result.append(definition)
	result.sort_custom(func(left: AbilityDefinition, right: AbilityDefinition):
		if left.slot == right.slot:
			return String(left.id) < String(right.id)
		return left.slot < right.slot
	)
	return result

func _default_effects(definition: AbilityDefinition) -> Array[AbilityEffect]:
	var effects: Array[AbilityEffect] = []
	var id := String(definition.id)
	if definition.passive:
		var passive := BuffDefinition.new()
		passive.id = StringName("passive_%s" % id)
		passive.tag = "super_armor"
		passive.duration = 3600.0
		passive.flat_modifiers = {"attack": 2.0, "defense": 1.0}
		var passive_effect := SelfBuffEffect.new()
		passive_effect.buff = passive
		effects.append(passive_effect)
		return effects
	if id in ["tjgl", "myhc", "lhsq"]:
		var heal := HealEffect.new()
		heal.maximum_ratio = 0.18
		heal.missing_ratio = 0.2
		effects.append(heal)
		return effects
	if id in ["jdy", "lys", "hytj", "fhf", "blq"]:
		var dash := DashEffect.new()
		dash.speed = 520.0
		dash.duration = 0.2
		effects.append(dash)
	var ranged := id in ["lyfb", "hmz", "qsez", "hyjj", "shy", "smb", "xbz", "jgz", "jhsj", "dgq", "jsp", "ssp", "syzq", "tmc", "xgq", "zznh", "dcj", "jdz", "mmw", "tkj", "wdww", "zq", "cxq", "lljy", "llrd", "tllz", "xyq", "ygth"]
	if ranged:
		var projectile := ProjectileEffect.new()
		projectile.power_scale = 0.85
		projectile.lifetime = 1.2
		projectile.speed = 360.0
		effects.append(projectile)
	else:
		var melee := MeleeEffect.new()
		melee.power_scale = 1.15
		melee.lifetime = 0.22
		effects.append(melee)
	return effects

func _effect_from_data(data: Dictionary) -> AbilityEffect:
	var effect: AbilityEffect
	match data.get("kind", ""):
		"projectile":
			effect = ProjectileEffect.new()
		"timeline_attack":
			effect = TimelineAttackEffect.new()
		"melee":
			effect = MeleeEffect.new()
		"heal":
			effect = HealEffect.new()
		"self_buff":
			effect = SelfBuffEffect.new()
		"dash":
			effect = DashEffect.new()
		_:
			return null
	for key: String in data:
		if key == "kind":
			continue
		if key == "buff":
			var buff := BuffDefinition.new()
			for property: String in data.buff:
				buff.set(property, data.buff[property])
			effect.set(key, buff)
		elif key == "offset" or key == "size_scale":
			effect.set(key, Vector2(float(data[key][0]), float(data[key][1])))
		else:
			effect.set(key, data[key])
	return effect
