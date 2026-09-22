class_name SkillLearningScreen
extends Node2D
## 复用原版技能学习窗口布局，列表内容由 AbilityCatalog 和当前角色数据驱动。

signal closed

var profile: PlayerProfile
var actor: CombatActor
var _show_passive := false
var _content: Control

@onready var _front_bg: ColorRect = $bg/lh_pic/front_bg
@onready var _title: Label = $bg/lh_pic/front_bg/Title
@onready var _gold: Label = $bg/lh_pic/lh_value

func setup(owner_profile: PlayerProfile, owner_actor: CombatActor) -> void:
	profile = owner_profile
	actor = owner_actor
	_refresh()

func _ready() -> void:
	_refresh()

func _on_zd_skill_pressed() -> void:
	_show_passive = false
	_refresh()

func _on_bd_skill_pressed() -> void:
	_show_passive = true
	_refresh()

func _on_close_pressed() -> void:
	closed.emit()
	queue_free()

func _refresh() -> void:
	if not is_node_ready() or profile == null:
		return
	if is_instance_valid(_content):
		_content.queue_free()
	_content = Control.new()
	_content.name = "SkillRows"
	_content.position = Vector2(18, 64)
	_content.size = Vector2(780, 355)
	_front_bg.add_child(_content)
	_title.text = "被动技能" if _show_passive else "主动技能"
	_gold.text = str(profile.progression.gold)
	var character_id := CharacterAbilityRegistry.character_id(profile.selected_skin)
	var character_names := {1: "悟空", 2: "唐僧", 3: "八戒", 4: "沙僧", 5: "白龙"
	}
	_title.text = "%s·%s" % [character_names.get(character_id, "角色"), "被动技能" if _show_passive else "主动技能"]
	var definitions := profile.ability_catalog.for_character(character_id, true)
	var row := 0
	for definition: AbilityDefinition in definitions:
		if definition.passive != _show_passive:
			continue
		_add_skill_row(definition, row)
		row += 1
	if row == 0:
		var empty := Label.new()
		empty.text = "当前角色暂无此类技能"
		empty.position = Vector2(280, 130)
		empty.add_theme_font_size_override("font_size", 22)
		_content.add_child(empty)

func _add_skill_row(definition: AbilityDefinition, row: int) -> void:
	var y := float(row * 56)
	var icon := TextureRect.new()
	icon.position = Vector2(10, y + 4)
	icon.size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture = _skill_icon(definition)
	_content.add_child(icon)
	var name := Label.new()
	name.text = definition.display_name if not definition.display_name.is_empty() else String(definition.id)
	name.position = Vector2(66, y + 7)
	name.size = Vector2(190, 24)
	name.add_theme_font_size_override("font_size", 19)
	_content.add_child(name)
	var description := Label.new()
	description.text = definition.description
	description.position = Vector2(66, y + 29)
	description.size = Vector2(500, 24)
	description.clip_text = true
	description.add_theme_font_size_override("font_size", 14)
	_content.add_child(description)
	var state := Label.new()
	state.text = "已注册" if actor != null and actor.abilities.has_ability(definition.id) else "可学习"
	state.position = Vector2(625, y + 12)
	state.size = Vector2(92, 30)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state.add_theme_font_size_override("font_size", 17)
	_content.add_child(state)

func _skill_icon(definition: AbilityDefinition) -> Texture2D:
	var icon_id := definition.legacy_id if not definition.legacy_id.is_empty() else definition.animation
	var path := "res://assets/Art/Skill/SkillIcon/%s.png" % icon_id
	return load(path) if not icon_id.is_empty() and ResourceLoader.exists(path) else load("res://assets/Art/Skill/LittleSkillIcon/Empty.png")
