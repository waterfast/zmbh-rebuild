class_name LevelPreview
extends Control

signal closed
signal challenge_requested(level_id: StringName)

var level_id: StringName
var profile: PlayerProfile
var spawn_speed_multiplier: int = 1

func _ready() -> void:
	$ColorRect/TextureRect/Speed/speedtext.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$ColorRect/TextureRect/Close.pressed.connect(closed.emit)
	$ColorRect/TextureRect/Challenge.pressed.connect(func(): challenge_requested.emit(level_id))
	$ColorRect/TextureRect/Speed.pressed.connect(_toggle_spawn_speed)
	var previews: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/maps/level_previews.json"))
	var data: Dictionary = previews.get(String(level_id), {})
	if data.is_empty():
		$ColorRect/TextureRect/Challenge.disabled = true
		return
	$ColorRect/TextureRect/Title.text = data.LevelName
	$ColorRect/TextureRect/Level/LevelDown.text = str(data.Level)
	$ColorRect/TextureRect/pj.text = "%s历史最高评价：" % data.LevelName
	$ColorRect/TextureRect/pj/MyPj.text = "暂无"
	$ColorRect/TextureRect/Fall.text = "%s原版概率掉落：" % data.LevelName
	$ColorRect/TextureRect/Fall.tooltip_text = "原版掉落预览；完整掉落规则尚未迁移。"
	$ColorRect/TextureRect/Mybg.texture = load(data.background_path)
	$ColorRect/TextureRect/Speed/speedtext.text = "×1"
	for monster: Dictionary in data.MonsterList:
		var portrait: TextureRect = load("res://Scene/OtherScene/MonsterHeadInfo.tscn").instantiate()
		portrait.get_node("pic").texture = load(monster.icon_path)
		portrait.get_node("Boss").visible = bool(monster.IsBoss)
		portrait.get_node("MonsterName").text = monster.display_name
		$ColorRect/TextureRect/ScrollContainer2/MonsterList.add_child(portrait)
	for item: String in data.LevelFall:
		var icon: Button = load("res://Scene/UI/QuestRewardIcon.tscn").instantiate()
		icon.icon = load("res://assets/Art/BackPack/AllItems/%s.png" % item)
		var definition := profile.catalog.get_definition(StringName(item)) if profile != null else null
		icon.tooltip_text = str(definition.metadata().get("名字", item)) if definition != null else item
		$ColorRect/TextureRect/ScrollContainer/FallList.add_child(icon)

func _toggle_spawn_speed() -> void:
	spawn_speed_multiplier = 2 if spawn_speed_multiplier == 1 else 1
	$ColorRect/TextureRect/Speed/speedtext.text = "×%d" % spawn_speed_multiplier
