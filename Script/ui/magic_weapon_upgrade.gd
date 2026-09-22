class_name MagicWeaponUpgrade
extends Node2D
## 原版法宝成长窗口，与实战技能选择是两个不同入口。
signal closed
signal changed
var profile: PlayerProfile
var actor: CombatActor
var service: RelicProgression
var _presentation: Dictionary = {}
var _dialog: Node

func setup(owner_profile: PlayerProfile, owner_actor: CombatActor) -> void:
	profile = owner_profile
	actor = owner_actor
	_presentation = JSON.parse_string(FileAccess.get_file_as_string("res://content/combat/relic_presentation.json"))
	service = RelicProgression.new(profile.inventory, profile.progression)
	profile.equipment.changed.connect(_equipment_changed)
	_refresh()

func _equipment_changed(_slot: StringName) -> void:
	_refresh()

func _item() -> ItemInstance:
	return profile.equipment.equipped(&"relic") if profile != null and profile.equipment != null else null

func _refresh() -> void:
	var item := _item()
	var has_relic := item != null
	for path: String in ["BG/bg_2/up_level", "BG/wxxl", "BG/gjwx", "BG/czlxl"]:
		get_node(path).disabled = not has_relic
	$BG/Icon.visible = has_relic
	$BG/Icon_.visible = false
	$BG/Name_.text = "请先在背包中装备法宝"
	$BG/MagicWeaponSkillTitle.text = ""
	$BG/ScrollContainer/VBoxContainer/MagicWeaponSkill.text = ""
	$BG/ScrollContainer/VBoxContainer/PsTitle.text = ""
	$BG/ScrollContainer/VBoxContainer/MagicWeaponSkill2.text = ""
	for field: String in ["m_level", "m_czl", "m_wx", "m_Hp", "m_Mp", "m_Power", "m_Def", "m_MDef"]:
		get_node("BG/bg_2/" + field).text = "—"
	$BG/bg_2/lh_bar.value = 0
	$BG/bg_2/lh_bar/lh_value.text = ""
	if not has_relic:
		return
	var definition := profile.catalog.get_definition(item.definition_id)
	var stats := definition.stats(item)
	$BG/MagicWeaponSkillTitle.text = _presentation.get(String(item.definition_id), {}).get("skill", "")
	$BG/Name_.text = str(definition.metadata().get("名字", item.definition_id))
	$BG/bg_2/m_level.text = str(item.enhancement)
	$BG/bg_2/m_czl.text = str(item.rolls.get("成长率", 1.0))
	$BG/bg_2/m_wx.text = "".join(item.elements)
	var fields := {"m_Hp": &"max_hp", "m_Mp": &"max_mp", "m_Power": &"attack", "m_Def": &"defense", "m_MDef": &"magic_defense"}
	for field: String in fields:
		get_node("BG/bg_2/" + field).text = str(snappedf(float(stats.get(fields[field], 0.0)), 0.01))
	var required := service.cost(item)
	$BG/bg_2/lh_bar.value = float(profile.progression.gold) / maxf(1, required)
	$BG/bg_2/lh_bar/lh_value.text = "满级" if required == 0 else "%d/%d" % [profile.progression.gold, required]
	$BG/bg_2/up_level.disabled = item.enhancement >= 10
	$BG/ScrollContainer/VBoxContainer/MagicWeaponSkill.text = str(definition.metadata().get("描述", ""))
	if $BG/IconPlayer.has_animation(item.definition_id):
		$BG/IconPlayer.play(item.definition_id)
	else:
		$BG/Icon.hide()
		var icon_path := "res://assets/Art/BackPack/Equipment/%s.png" % item.definition_id
		if ResourceLoader.exists(icon_path):
			$BG/Icon_.texture = load(icon_path)
			$BG/Icon_.show()

func _on_up_level_pressed() -> void:
	var item := _item()
	if item != null:
		_result(service.upgrade(item.uid))

func _result(error: String) -> void:
	if error.is_empty():
		changed.emit()
	else:
		GameNotification.show_message(self, error, 1.5, Vector2.ZERO)
	_refresh()

func _on_close_pressed() -> void:
	closed.emit()
	queue_free()

func _on_szfb_pressed() -> void:
	if is_instance_valid(_dialog):
		return
	_dialog = load("res://Scene/UI/MagicWeaponPanel.tscn").instantiate()
	add_child(_dialog)
	_dialog.setup(profile, actor)
	_dialog.changed.connect(changed.emit)

func _on_tips_pressed() -> void:
	if is_instance_valid(_dialog):
		return
	_dialog = load("res://Scene/UI/MagicWeaponHelp.tscn").instantiate()
	_dialog.position = Vector2.ZERO
	add_child(_dialog)
	_dialog.get_node("BG/Close").pressed.connect(_dialog.queue_free)

func _on_wxxl_pressed() -> void:
	_confirm_refine(&"elements", "确定使用1颗五行洗炼石洗炼法宝吗？")

func _on_gjwx_pressed() -> void:
	var item := _item()
	if item != null:
		_confirm_refine(&"advanced", "确定使用%d颗五行洗炼石高级洗炼法宝吗？" % maxi(1, item.elements.size() * 5))

func _on_czlxl_pressed() -> void:
	_confirm_refine(&"growth", "确定使用1颗成长率洗炼石洗炼法宝吗？")

func _confirm_refine(kind: StringName, message: String) -> void:
	var item := _item()
	if item == null or is_instance_valid(_dialog):
		return
	var uid := item.uid
	_dialog = load("res://Scene/show_text/choose_scene.tscn").instantiate()
	_dialog.message_text = message
	_dialog.confirmation_delay = 0.0
	_dialog.confirmed.connect(func(): _result(service.refine(uid, kind)))
	add_child(_dialog)
