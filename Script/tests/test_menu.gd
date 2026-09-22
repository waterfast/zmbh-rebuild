extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var menu: Node2D = load("res://Scene/UI/MainMenu.tscn").instantiate()
	var temporary_path := "user://menu_test_%d.json" % Time.get_ticks_usec()
	menu.archives = ArchiveStore.new(temporary_path)
	root.add_child(menu)
	check(menu.get_node("background").position == Vector2(470, 295), "保留原主菜单背景坐标")
	check(menu.get_node("ButtonList").position == Vector2(686, 131), "保留原按钮列位置")
	check(menu.get_node("ButtonList").get_child_count() == 15, "保留八个原按钮和七条分隔图像")
	check(menu.get_node("background/name").text == "造梦西游之", "保留原标题节点和内容")
	menu._on_begin_game_pressed()
	var archive: ArchiveScreen = menu._archive_screen
	check(archive.scene_file_path == "res://Scene/ArchiveInterface/read_archive_interface.tscn", "读档按钮实例化原档位选择场景")
	check(archive.get_node("ScrollContainer/AllAr").get_child_count() == 6, "默认显示六个原档位控件")
	check(archive.get_node("background").position == Vector2(471, 294), "保留原档位选择窗口位置")
	menu._on_begin_game_pressed()
	check(menu.get_node("ar_infer").get_child_count() == 1, "重复点击不叠加档位窗口")
	check(archive.get_node("ScrollContainer/AllAr").get_child(0).get_node("InfoBox/LevelAndRole").text == "空存档", "空档保留原提示")
	var profile := PlayerProfile.new()
	profile.start_new()
	var store: SaveStore = menu.archives.store_for(1)
	check(store.save_data(profile.serialize()), "测试档可保存")
	var initial_content := FileAccess.get_file_as_string(temporary_path)
	menu._on_game_warn_pressed()
	var notice := menu.get_child(menu.get_child_count() - 1) as GameNotification
	check(notice != null and notice.scene_file_path == "res://Scene/show_text/Message_show.tscn", "菜单反馈复用原提示动画场景")
	check(notice.message_text.contains("尚未迁移"), "未迁移功能明确提示")
	archive._select_slot(1)
	var destination := current_scene
	check(destination is MapScreen and destination.profile != null, "选档向原地图场景注入档案")
	check(destination.save_store.path == temporary_path, "选档同时传入独立档位存储")
	check(destination.profile.inventory.item_ids().size() == profile.inventory.item_ids().size(), "继续恢复原物品实例")
	check(FileAccess.get_file_as_string(temporary_path) == initial_content, "进入游戏不覆盖存档")
	destination.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
	print("MENU TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
