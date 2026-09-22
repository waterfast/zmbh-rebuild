class_name BuffInstance
extends RefCounted

var definition: BuffDefinition
var source: StringName
var remaining: float
var elapsed: float = 0.0
var hit: HitData
var modifier_source: StringName

func _init(data: BuffDefinition, origin: StringName, payload: HitData) -> void:
	definition = data
	source = origin
	remaining = data.duration
	hit = payload
	modifier_source = StringName("buff:%d" % get_instance_id())
