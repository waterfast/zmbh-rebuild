class_name MapScreen
extends Node2D
## 地图只装配原场景节点；档案和存档实例跨地图、战斗显式传递。

@export var page: int = 1
var profile: PlayerProfile
var save_store: SaveStore
var overlay: Node
var _routes: Dictionary = {}
var _layer: CanvasLayer
var _transitioning: bool = false

static func page_for_level(id: StringName) -> int:
	var number := int(String(id).trim_prefix("level_"))
	if number <= 10:
		return 1
	if number <= 21:
		return 2
	if number <= 30:
		return 3
	return 4

static func create_for_profile(player_profile: PlayerProfile, store: SaveStore) -> MapScreen:
	var screen := load("res://Scene/Main_menu/Map_%d.tscn" % page_for_level(player_profile.last_level)).instantiate() as MapScreen
	screen.profile = player_profile
	screen.save_store = store
	return screen

func _ready() -> void:
	if profile == null:
		profile = PlayerProfile.new()
		profile.start_new()
	profile.detach_actor()
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)
	var all_routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/maps/routes.json"))
	_routes = all_routes.get(str(page), {})
	for path: String in _routes:
		var button := get_node_or_null(path) as BaseButton
		if button == null:
			continue
		var route: Dictionary = _routes[path]
		button.pressed.connect(_activate.bind(path))
		if route.kind == "level":
			button.disabled = not is_level_unlocked(StringName(route.id))
			if not button.disabled and not profile.progression.cleared_levels.has(String(route.id)):
				_play_highlight(button.name)
		elif route.kind == "map":
			button.disabled = not _map_unlocked(int(route.page))
		elif route.kind == "unavailable":
			button.disabled = false
			button.tooltip_text = "此功能尚未迁移"
	var vortex := get_node_or_null("Level2") as AnimationPlayer
	if vortex != null and is_level_unlocked(&"level_9") and vortex.has_animation(&"szwl"):
		vortex.play(&"szwl")

func is_level_unlocked(id: StringName) -> bool:
	if id == &"level_1" or profile.progression.cleared_levels.has(String(id)):
		return true
	var number := int(String(id).trim_prefix("level_"))
	# 原地图由望乡台直接进入 Level_21，Level_20 没有原选关按钮。
	var previous := 19 if number == 21 else number - 1
	return profile.progression.cleared_levels.has("level_%d" % previous)

func _map_unlocked(target_page: int) -> bool:
	if target_page <= page:
		return true
	var entrance := [&"", &"level_1", &"level_11", &"level_22", &"level_31"]
	return target_page < entrance.size() and is_level_unlocked(entrance[target_page])

func _play_highlight(button_name: StringName) -> void:
	var normalized := String(button_name).to_lower().replace("_", "")
	for child in get_children():
		if child is AnimationPlayer:
			for animation: StringName in child.get_animation_list():
				if String(animation).to_lower().replace("_", "") == normalized:
					child.play(animation)

func _activate(path: String) -> void:
	if _transitioning or is_instance_valid(overlay):
		return
	var route: Dictionary = _routes.get(path, {})
	match String(route.get("kind", "unavailable")):
		"level":
			show_level(StringName(route.id))
		"map":
			if _map_unlocked(int(route.page)):
				var screen := load("res://Scene/Main_menu/Map_%d.tscn" % int(route.page)).instantiate() as MapScreen
				screen.profile = profile
				screen.save_store = save_store
				_replace_scene(screen)
		"menu":
			_replace_scene(load("res://Scene/UI/MainMenu.tscn").instantiate())
		"quest":
			_open_panel("res://Scene/UI/QuestJournal.tscn")
		"shop":
			_open_panel("res://Scene/Shop/SHOP.tscn")
		"save":
			_save()
		_:
			GameNotification.show_message(_layer, "此功能尚未迁移。")

func show_level(id: StringName) -> void:
	if not is_level_unlocked(id) or is_instance_valid(overlay):
		return
	var preview := load("res://Scene/OtherScene/LevelInfo.tscn").instantiate() as LevelPreview
	preview.level_id = id
	preview.profile = profile
	preview.closed.connect(_close_overlay)
	preview.challenge_requested.connect(start_level)
	overlay = preview
	_layer.add_child(preview)

func start_level(id: StringName) -> void:
	if _transitioning or not is_level_unlocked(id):
		return
	profile.last_level = id
	var app: Node = load("res://app/game_app.tscn").instantiate()
	app.profile = profile
	app.save_store = save_store if save_store != null else SaveStore.new("user://zaomeng_profile.json")
	app.load_saved_profile = false
	_replace_scene(app)

func _open_panel(path: String) -> void:
	if not ResourceLoader.exists(path):
		GameNotification.show_message(_layer, "此功能尚未迁移。")
		return
	overlay = load(path).instantiate()
	overlay.profile = profile
	overlay.closed.connect(_close_overlay)
	_layer.add_child(overlay)

func _close_overlay() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null

func _save() -> void:
	if save_store == null:
		GameNotification.show_message(_layer, "请先从主菜单选择存档。")
		return
	var saved := save_store.save_data(profile.serialize())
	GameNotification.show_message(_layer, "保存成功！" if saved else save_store.last_error)

func _replace_scene(scene: Node) -> void:
	_transitioning = true
	var tree := get_tree()
	tree.root.add_child(scene)
	tree.current_scene = scene
	queue_free()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE and is_instance_valid(overlay):
		_close_overlay()
		get_viewport().set_input_as_handled()
