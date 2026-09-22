extends Node2D
## 菜单和档位界面使用原场景；档案通过显式参数传给运行中的游戏。

var archives := ArchiveStore.new()
var _archive_screen: ArchiveScreen
var _character_screen: CharacterSelectScreen
var _settings_screen: SettingsScreen
var _settings_store := SettingsStore.new()
var _entering: bool = false

func _on_begin_game_pressed() -> void:
	if is_instance_valid(_archive_screen):
		return
	_archive_screen = load("res://Scene/ArchiveInterface/read_archive_interface.tscn").instantiate() as ArchiveScreen
	_archive_screen.archives = archives
	_archive_screen.require_character_selection = true
	_archive_screen.profile_selected.connect(_enter_game)
	_archive_screen.new_profile_requested.connect(_open_character_selection)
	$ar_infer.add_child(_archive_screen)

func _open_character_selection(profile: PlayerProfile, store: SaveStore) -> void:
	if is_instance_valid(_character_screen):
		return
	_character_screen = load("res://Scene/Main_menu/ChoosePlayer.tscn").instantiate() as CharacterSelectScreen
	_character_screen.profile = profile
	_character_screen.store = store
	_character_screen.confirmed.connect(_enter_game)
	_character_screen.cancelled.connect(func():
		_character_screen = null
	)
	$ar_infer.add_child(_character_screen)

func _enter_game(profile: PlayerProfile, store: SaveStore) -> void:
	if _entering:
		return
	_entering = true
	var map := MapScreen.create_for_profile(profile, store)
	var tree := get_tree()
	tree.root.add_child(map)
	tree.current_scene = map
	queue_free()

func _show_notice(message: String) -> void:
	GameNotification.show_message(self, message, 2.0)

func _on_music_pressed() -> void:
	_show_notice("音乐切换功能尚未迁移。")

func _on_gmae_help_pressed() -> void:
	_show_notice("A/D 移动，K 跳跃，J 普攻，Y/U/I/O/L 技能。B 背包，Q 任务，E 前进。")

func _on_tiaoguo_pressed() -> void:
	_show_notice("剧情系统尚未迁移，暂时无法切换剧情播放。")

func _on_change_bg_pressed() -> void:
	_show_notice("背景选择功能尚未迁移。")

func _on_game_set_pressed() -> void:
	if is_instance_valid(_settings_screen):
		return
	_settings_screen = load("res://Scene/UI/GameSettings.tscn").instantiate() as SettingsScreen
	_settings_screen.setup(_settings_store)
	_settings_screen.closed.connect(func(): _settings_screen = null)
	add_child(_settings_screen)

func _on_game_warn_pressed() -> void:
	_show_notice("原版游戏须知页面尚未迁移。")

func _on_letter_pressed() -> void:
	_show_notice("原版给玩家的一封信页面尚未迁移。")
