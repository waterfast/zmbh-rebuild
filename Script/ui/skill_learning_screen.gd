class_name SkillLearningScreen
extends Node2D
## 原版三张场景负责布局，SkillProgression 负责交易、成长和键位。
signal closed
signal changed
var profile: PlayerProfile
var actor: CombatActor
var _content: Control
var _show_passive := false
var _dialog: Node

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
		_content.free()
	$bg/lh_pic/lh_value.text = str(profile.progression.gold)
	$bg/lh_pic/front_bg/Title.text = "被动技能" if _show_passive else "主动技能"
	_content = load("res://Scene/UI/Skill/%s.tscn" % ("PassiveSkills" if _show_passive else "ActiveSkills")).instantiate()
	_content.position = Vector2(10, 50) if _show_passive else Vector2(40, 50)
	$bg/lh_pic/front_bg.add_child(_content)
	if _show_passive:
		_populate_passive()
	else:
		_populate_active()

func _populate_active() -> void:
	var rows := _content.get_node("ScrollContainer/HBoxContainer")
	for definition: AbilityDefinition in profile.ability_catalog.for_character(CharacterAbilityRegistry.character_id(profile.selected_skin)):
		var index := definition.slot
		var icon: Button = rows.get_node("sk_pi/ski_%d" % index)
		var path := definition.icon_path
		if ResourceLoader.exists(path):
			icon.icon = load(path)
		icon.pressed.connect(_choose_key.bind(definition))
		rows.get_node("Sk_na/skill_%d" % index).text = definition.display_name
		rows.get_node("sk_le/sk_%d" % index).text = "Lv:%d" % profile.skills.level(definition.id)
		rows.get_node("sk_ms/s_%d" % index).text = definition.description
		var upgrade: BaseButton = rows.get_node("sk_lv/Skill_%d" % index)
		upgrade.get_node("Need").text = "需：%d灵魂" % profile.skills.cost(definition)
		upgrade.disabled = profile.skills.level(definition.id) >= (10 if definition.passive else 1)
		upgrade.pressed.connect(_confirm_learning.bind(definition))

func _populate_passive() -> void:
	var rows := _content.get_node("HBoxContainer")
	for index in range(6):
		var level := int(profile.skills.passives.get(SkillProgression.PASSIVE_NAMES[index], 0))
		rows.get_node("Current_e/name_%d" % (index + 1)).text = "当前：%s" % SkillProgression.PASSIVE_VALUES[index][level]
		rows.get_node("Next_e/name_%d" % (index + 1)).text = "满级" if level >= 6 else "升级后：%s" % SkillProgression.PASSIVE_VALUES[index][level + 1]
		rows.get_node("NeedLh/name_%d" % (index + 1)).text = str((level + 1) * 5000)
		var button: BaseButton = rows.get_node("Up_level/up_%d" % (index + 1))
		button.disabled = level >= 6
		button.pressed.connect(_confirm_passive.bind(index))

func _confirm_learning(definition: AbilityDefinition) -> void:
	_confirm("确定消耗%d灵魂升级%s吗？" % [profile.skills.cost(definition), definition.display_name], func():
		_result(profile.skills.learn(definition, CharacterAbilityRegistry.character_id(profile.selected_skin), profile.progression)))

func _confirm_passive(index: int) -> void:
	_confirm("确定升级%s吗？" % SkillProgression.PASSIVE_NAMES[index], func():
		_result(profile.skills.learn_passive(index, profile.progression)))

func _result(error: String) -> void:
	if not error.is_empty():
		GameNotification.show_message(self, error, 1.5, Vector2.ZERO)
	else:
		changed.emit()
	_refresh()

func _confirm(message: String, action: Callable) -> void:
	if is_instance_valid(_dialog):
		return
	_dialog = load("res://Scene/show_text/choose_scene.tscn").instantiate()
	_dialog.message_text = message
	_dialog.confirmation_delay = 0.0
	_dialog.confirmed.connect(action)
	add_child(_dialog)

func _choose_key(definition: AbilityDefinition) -> void:
	if definition.passive:
		return
	if profile.skills.level(definition.id) == 0:
		GameNotification.show_message(self, "先学习技能才能设置按键", 1.5, Vector2.ZERO)
		return
	if is_instance_valid(_dialog):
		return
	_dialog = load("res://Scene/UI/Skill/SkillKeySet.tscn").instantiate()
	add_child(_dialog)
	_dialog.get_node("BG/Label").text = "设置技能“%s”按键" % definition.display_name
	for index in range(5):
		_dialog.get_node("BG/" + ["Y", "U", "I", "O", "L"][index]).pressed.connect(func():
			profile.skills.assign(index, definition, CharacterAbilityRegistry.character_id(profile.selected_skin))
			changed.emit()
			_dialog.queue_free())
	_dialog.get_node("Close").pressed.connect(_dialog.queue_free)
