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
	root.size = Vector2i(940, 590)
	var screen := load("res://Scene/UI/QuestJournal.tscn").instantiate() as QuestScreen
	screen.profile = PlayerProfile.new()
	root.add_child(screen)
	await process_frame
	check(screen.get_node("BG").position == Vector2(471, 296), "任务背景保持旧 Scene 坐标")
	check(screen.get_node("BG/ms").position == Vector2(93, -104), "任务描述区保持旧坐标")
	check(screen.get_node("BG/jl").position == Vector2(94, 30), "奖励区保持旧坐标")
	check(screen.get_node("BG/Close") is TextureButton, "关闭保留旧贴图按钮")
	var task_list: VBoxContainer = screen.get_node("BG/ScrollContainer/TaskList")
	check(task_list.get_child_count() == screen.profile.quests.entries().size(), "任务标题实例绑定现有任务")
	check(task_list.get_child(0).get_node("Tilte").text == "花果山历练", "任务标题显示数据内容")
	var reward_list: GridContainer = screen.get_node("BG/jl/ScrollContainer/RewardList")
	check(reward_list.get_child_count() == 2, "奖励行展示现有经验和魂值")
	check(reward_list.get_child(0).get_node("Items").text.is_empty(), "不以文字伪造原奖励图标")
	var claim: TextureButton = screen.get_node("BG/lqjl")
	check(claim.disabled, "未完成任务禁止领奖")
	screen.profile.quests.record(&"enemy_defeated", &"monster_1", 5)
	check(not claim.disabled, "任务事件即时启用原领奖按钮")
	var gold_before: int = screen.profile.progression.gold
	claim.pressed.emit()
	check(screen.profile.progression.gold == gold_before + 100, "原领奖按钮接入新成长奖励")
	check(claim.disabled, "领奖后禁用按钮")
	claim.pressed.emit()
	check(screen.profile.progression.gold == gold_before + 100, "重复调用不重复发奖励")
	screen.get_node("BG/TaskType/RcTask").pressed.emit()
	check(task_list.get_child_count() == 0 and claim.disabled, "未迁移日常任务显示空列表且不能领奖")
	screen.get_node("BG/TaskType/HdTask").pressed.emit()
	check(task_list.get_child_count() == 2, "原页签切回活动任务")
	var closed_events: Array[bool] = []
	screen.closed.connect(func(): closed_events.append(true))
	paused = true
	check(screen.can_process(), "暂停时任务面板仍处理输入")
	var close: TextureButton = screen.get_node("BG/Close")
	var mouse := InputEventMouseButton.new()
	mouse.position = close.get_global_rect().get_center()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	root.push_input(mouse)
	await process_frame
	mouse = mouse.duplicate()
	mouse.pressed = false
	root.push_input(mouse)
	await process_frame
	check(closed_events.size() == 1, "暂停时实际点击旧关闭按钮发出关闭信号")
	paused = false
	screen.queue_free()
	await process_frame
	print("QUEST UI TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
