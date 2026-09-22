class_name AbilityGrant
extends RefCounted
## 一份技能授予记录；定义和授予来源分开，卸载时可精确撤销单个来源。

var definition: AbilityDefinition
var source_id: StringName
var category: StringName
var source_kind: StringName

func _init(
	ability: AbilityDefinition = null,
	source: StringName = &"",
	grant_category: StringName = &"",
	grant_source_kind: StringName = &""
) -> void:
	definition = ability
	source_id = source
	category = grant_category if not grant_category.is_empty() else (ability.category if ability != null else &"character")
	source_kind = grant_source_kind if not grant_source_kind.is_empty() else category
