class_name ItemInstance
extends RefCounted
## 仅记录变化量和一次性随机结果；不复制图标、描述、强化表等静态数据。

var uid: StringName
var definition_id: StringName
var roll_source: StringName = &"unknown"
var roll_level: int = 1
var rolls: Dictionary = {}
var enhancement: int = 0
var elements: Array = []
var gems: Array = []

func serialize() -> Dictionary:
	return {"uid": String(uid), "definition_id": String(definition_id), "roll_source": String(roll_source), "roll_level": roll_level, "rolls": rolls.duplicate(true), "enhancement": enhancement, "elements": elements.duplicate(), "gems": gems.duplicate(true)}

static func from_data(data: Dictionary) -> ItemInstance:
	var instance := ItemInstance.new()
	instance.uid = StringName(data.get("uid", ""))
	instance.definition_id = StringName(data.get("definition_id", ""))
	instance.roll_source = StringName(data.get("roll_source", "unknown"))
	instance.roll_level = maxi(1, int(data.get("roll_level", 1)))
	instance.rolls = data.get("rolls", {}).duplicate(true)
	instance.enhancement = int(data.get("enhancement", 0))
	instance.elements = data.get("elements", []).duplicate()
	instance.gems = data.get("gems", []).duplicate(true)
	return instance
