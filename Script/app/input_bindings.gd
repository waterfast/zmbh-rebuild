class_name GameInputBindings
extends RefCounted

static func install() -> void:
	var keys := {
		&"move_left": KEY_A, &"move_right": KEY_D, &"jump": KEY_K,
		&"attack": KEY_J, &"ability_0": KEY_Y, &"ability": KEY_U, &"ability_2": KEY_I,
		&"ability_3": KEY_O, &"ability_4": KEY_L, &"ability_5": KEY_P, &"inventory": KEY_B,
		&"magic_weapon": KEY_H, &"quests": KEY_Q, &"pause": KEY_ESCAPE, &"interact": KEY_E, &"save": KEY_F5,
	}
	for action_name: StringName in keys:
		if InputMap.has_action(action_name):
			continue
		InputMap.add_action(action_name)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action_name]
		InputMap.action_add_event(action_name, event)
