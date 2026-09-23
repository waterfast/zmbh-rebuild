class_name CharacterActionCatalog
extends RefCounted
## 清单仅记录原动画时长/倍速，角色场景按需加载。
static var _index: Dictionary = {}

static func metadata(character: int, animation: StringName) -> Dictionary:
	if _index.is_empty():
		_index = JSON.parse_string(FileAccess.get_file_as_string("res://content/abilities/action_timelines.json"))
	return _index.get(str(character), {}).get(String(animation), {})

static func configure(definition: AbilityDefinition, character: int) -> AbilityDefinition:
	var mapped := StringName({"hmz": "hmz__", "smb": "smb_1", "qlj": "qlj_1", "dcj": "dcj_1", "tkj": "tkj_1", "mmw": "mmw_1", "zq": "zq_1", "lhsq": "mbyj"}.get(String(definition.animation), String(definition.animation)))
	var data := metadata(character, mapped)
	if data.is_empty():
		return definition
	var result := definition.duplicate(true) as AbilityDefinition
	result.character_id = character
	result.animation = mapped
	result.cast_duration = float(data.duration)
	# 原碰撞轨道替换通用近战矩形，远程/治疗等效果仍经过效果接口。
	if bool(data.hitbox):
		var retained: Array[AbilityEffect] = []
		for effect: AbilityEffect in result.effects:
			if effect is MeleeEffect or (effect is ProjectileEffect and character == 1):
				result.power_scale = effect.power_scale
			else:
				retained.append(effect)
		result.effects = retained
	CharacterSpellCatalog.configure(result, data)
	return result

static func present(actor: CombatActor, definition: AbilityDefinition) -> CharacterActionTimeline:
	var data := metadata(definition.character_id, definition.animation)
	if data.is_empty():
		return null
	var scene := load("res://Scene/Combat/Character%dActions.tscn" % definition.character_id) as PackedScene
	var timeline := scene.instantiate() as CharacterActionTimeline
	timeline.actor = actor
	timeline.definition = definition
	timeline.playback_speed = float(data.speed)
	timeline.use_hitbox = bool(data.hitbox)
	actor.add_child(timeline)
	return timeline

static func present_status(actor: CombatActor, character: int, animation: StringName) -> CharacterActionTimeline:
	if metadata(character, animation).is_empty():
		return null
	var definition := AbilityDefinition.new()
	definition.character_id = character
	definition.animation = animation
	return present(actor, definition)
