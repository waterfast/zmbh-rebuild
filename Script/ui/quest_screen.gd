class_name QuestScreen
extends Control

signal closed

const TITLE_SCENE := preload("res://Scene/UI/QuestTitle.tscn")
const REWARD_SCENE := preload("res://Scene/UI/QuestReward.tscn")

var profile: PlayerProfile
var _selected_id: String = ""
var _category: String = "activity"
var _entries: Array[Dictionary] = []

@onready var _task_list: VBoxContainer = $BG/ScrollContainer/TaskList
@onready var _reward_list: GridContainer = $BG/jl/ScrollContainer/RewardList
@onready var _description: Label = $BG/ms/ScrollContainer/Text
@onready var _claim_button: TextureButton = $BG/lqjl

func _ready() -> void:
	$BG/Close.pressed.connect(closed.emit)
	$BG/TaskType/HdTask.pressed.connect(_set_category.bind("activity"))
	$BG/TaskType/RcTask.pressed.connect(_set_category.bind("daily"))
	_claim_button.pressed.connect(_claim_selected)
	if profile != null:
		profile.quests.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	_entries.clear()
	if profile != null:
		for entry: Dictionary in profile.quests.entries():
			if String(entry.get("category", "activity")) == _category:
				_entries.append(entry)
	var selected_exists := false
	var completed := 0
	_clear_rows(_task_list)
	for entry: Dictionary in _entries:
		selected_exists = selected_exists or String(entry.id) == _selected_id
		if int(entry.progress) >= int(entry.goal):
			completed += 1
		var button := TITLE_SCENE.instantiate() as TextureButton
		button.set_meta("quest_id", String(entry.id))
		button.get_node("Tilte").text = entry.name
		button.get_node("Label").text = "已领取" if entry.claimed else ("可领取" if entry.progress >= entry.goal else "%d/%d" % [entry.progress, entry.goal])
		button.pressed.connect(_select.bind(String(entry.id)))
		_task_list.add_child(button)
	if not selected_exists:
		_selected_id = String(_entries[0].id) if not _entries.is_empty() else ""
	$BG/ColorRect/Title.text = "活动任务完成：" if _category == "activity" else "日常任务完成："
	$BG/ColorRect/Title/Num.text = "（%d/%d）" % [completed, _entries.size()]
	_show_selected()

func _set_category(category: String) -> void:
	_category = category
	_selected_id = ""
	_refresh()

func _select(id: String) -> void:
	_selected_id = id
	_show_selected()

func _show_selected() -> void:
	_clear_rows(_reward_list)
	_claim_button.disabled = true
	_description.text = "暂无任务"
	for button: TextureButton in _task_list.get_children():
		button.set_pressed_no_signal(String(button.get_meta("quest_id")) == _selected_id)
	for entry: Dictionary in _entries:
		if String(entry.id) != _selected_id:
			continue
		_description.text = "%s\n进度：%d / %d" % [entry.description, entry.progress, entry.goal]
		_claim_button.disabled = entry.claimed or entry.progress < entry.goal
		_claim_button.tooltip_text = "奖励已领取" if entry.claimed else "领取任务奖励"
		var reward: Dictionary = entry.get("reward", {})
		_add_reward("经验", int(reward.get("experience", 0)))
		_add_reward("魂值", int(reward.get("gold", 0)))
		return

func _add_reward(title: String, amount: int) -> void:
	if amount <= 0:
		return
	var row := REWARD_SCENE.instantiate() as TextureRect
	row.get_node("ScrollContainer/title").text = "%s\n× %d" % [title, amount]
	var icon := row.get_node("Items") as Button
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward_list.add_child(row)

func _claim_selected() -> void:
	if profile == null or _selected_id.is_empty():
		return
	var reward := profile.quests.claim(_selected_id)
	if not reward.is_empty():
		profile.progression.reward(int(reward.get("experience", 0)), int(reward.get("gold", 0)))

func _clear_rows(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
