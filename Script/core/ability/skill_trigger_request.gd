class_name SkillTriggerRequest
extends RefCounted
## 所有主动技能入口共用的请求对象；来源类别只用于筛选与表现，不改变执行管线。

var ability_id: StringName
var category: StringName
var source_id: StringName
var action: ActionState
var actor: Node2D
var input_action: StringName

func _init(
	requested_ability: StringName = &"",
	requested_category: StringName = &"",
	requested_source: StringName = &"",
	requested_action: ActionState = null,
	requested_actor: Node2D = null,
	requested_input: StringName = &""
) -> void:
	ability_id = requested_ability
	category = requested_category
	source_id = requested_source
	action = requested_action
	actor = requested_actor
	input_action = requested_input
