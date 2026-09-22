class_name InGameSettingsScreen
extends Control
## 原版 Scene/set_menu.tscn 的重构适配器，保留原节点、布局和按钮资源。

signal closed
signal exit_level_requested
signal exit_to_menu_requested

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _on_close_pressed() -> void:
	closed.emit()
	queue_free()

func _on_continue_game_pressed() -> void:
	closed.emit()
	queue_free()

func _on_continue_game_2_pressed() -> void:
	exit_level_requested.emit()
	queue_free()

func _on_continue_game_4_pressed() -> void:
	exit_to_menu_requested.emit()
	queue_free()

func _on_bgm_control_pressed() -> void:
	pass

func _on_role_or_monster_control_pressed() -> void:
	pass
