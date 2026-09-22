class_name PetPanel
extends Node2D
## 宠物入口先接入独立数据边界；原项目没有可迁移的宠物面板/宠物定义，因此不伪造角色内容。

signal closed

var profile: PlayerProfile
var actor: CombatActor

@onready var _title: Label = $bg/lh_pic/front_bg/Title
@onready var _gold: Label = $bg/lh_pic/lh_value
@onready var _front_bg: ColorRect = $bg/lh_pic/front_bg

func setup(owner_profile: PlayerProfile, owner_actor: CombatActor) -> void:
	profile = owner_profile
	actor = owner_actor

func _ready() -> void:
	_title.text = "宠物"
	_gold.text = str(profile.progression.gold) if profile != null else "0"
	var notice := Label.new()
	notice.text = "当前原版工程没有宠物定义和对应面板资源\n宠物数据入口已预留，后续内容可直接注册到此面板。"
	notice.position = Vector2(215, 165)
	notice.size = Vector2(420, 75)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_font_size_override("font_size", 19)
	_front_bg.add_child(notice)

func _on_zd_skill_pressed() -> void: pass
func _on_bd_skill_pressed() -> void: pass

func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
