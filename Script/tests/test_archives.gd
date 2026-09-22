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
	var path := "user://archive_test_%d.json" % Time.get_ticks_usec()
	var archives := ArchiveStore.new(path)
	check(archives.slot_count == 6, "默认六个档位")
	check(archives.store_for(1).path == path, "第一档兼容现有路径")
	check(archives.store_for(0) == null and archives.store_for(7) == null, "拒绝越界档位")
	check(not archives.remove_last_slot(), "原界面最少六档约束")
	check(archives.add_slot(), "增加档位并保存")
	check(ArchiveStore.new(path).slot_count == 7, "档位数量重开后保留")
	var profile := PlayerProfile.new()
	profile.start_new()
	profile.progression.gold = 123
	var slot_seven := archives.store_for(7)
	check(slot_seven.save_data(profile.serialize()), "第七档独立保存")
	check(not archives.store_for(1).exists(), "保存新档不覆盖第一档")
	check(not archives.remove_last_slot(), "不能隐藏仍有存档的最后一格")
	var screen: ArchiveScreen = load("res://Scene/ArchiveInterface/read_archive_interface.tscn").instantiate()
	screen.archives = archives
	root.add_child(screen)
	var selection: Array = []
	screen.profile_selected.connect(func(selected: PlayerProfile, store: SaveStore): selection.append([selected, store]))
	screen._select_slot(7)
	check(selection.size() == 1 and selection[0][0].progression.gold == 123, "已有档恢复对应档位数据")
	check(selection[0][1].path == slot_seven.path, "运行会话携带对应SaveStore")
	screen._select_slot(2)
	check(selection.size() == 2 and selection[1][0].progression.gold == 0, "空档创建新角色档案")
	check(not archives.store_for(2).exists(), "选择空档不提前写盘")
	var invalid := archives.store_for(3)
	invalid.save_data({"invalid": true})
	var before := FileAccess.get_file_as_string(invalid.path)
	screen._select_slot(3)
	check(selection.size() == 2, "坏档不当作新游戏启动")
	check(FileAccess.get_file_as_string(invalid.path) == before, "坏档保留原文件")
	screen.get_node("background/cd_number").text = "7"
	screen._on_delete_pressed()
	check(screen._confirmation.scene_file_path == "res://Scene/show_text/choose_scene.tscn", "删除使用原确认窗口")
	check(screen._confirmation.get_node("TextureRect/bg/qd").disabled, "保留删除冷静倒计时")
	screen._confirmation._on_qx_pressed()
	await process_frame
	check(slot_seven.exists(), "取消删除不修改档位")
	screen._on_delete_pressed()
	screen._confirmation._on_think_time_timeout()
	screen._confirmation._on_qd_pressed()
	await process_frame
	check(not slot_seven.exists(), "确认删除清空所选档位")
	check(archives.remove_last_slot() and archives.slot_count == 6, "空末档可缩减")
	screen.queue_free()
	await process_frame
	for candidate: String in [path, invalid.path, slot_seven.path, path.get_basename() + "_slots.json"]:
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(candidate + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate + suffix))
	print("ARCHIVE TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
