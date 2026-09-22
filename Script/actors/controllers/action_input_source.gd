class_name ActionInputSource
extends ActorInputSource
## InputMap 隔离物理设备。换键位或绑定手柄不需要修改角色。

var slots: Dictionary = {&"ability": &"ice_dragon_wave"}

func sample(command: ActorCommand) -> void:
	command.clear()
	command.movement = Input.get_axis(&"move_left", &"move_right")
	command.jump = Input.is_action_just_pressed(&"jump")
	command.attack = Input.is_action_just_pressed(&"attack")
	for action_name: StringName in slots:
		if InputMap.has_action(action_name) and Input.is_action_just_pressed(action_name):
			command.ability = slots[action_name]
			break
