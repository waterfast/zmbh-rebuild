class_name MagicWeaponPanel
extends Node2D
## 原版每页三个法宝技能条目；实战选择不会更换身上装备。
signal closed
signal changed
const ORDER := [&"dshl",&"tsgj",&"bsyj",&"lsys",&"xhmt",&"kyl",&"xhhl",&"qyj",&"zjfyd",&"zjhl"]
const PAGE_SIZE := 3
var profile: PlayerProfile
var actor: CombatActor
var _page := 0
var _rows: Array[Node] = []
var _presentation: Dictionary = {}
func setup(owner_profile: PlayerProfile, owner_actor: CombatActor) -> void:
	profile = owner_profile
	actor = owner_actor
	_presentation = JSON.parse_string(FileAccess.get_file_as_string("res://content/combat/relic_presentation.json"))
	_refresh()
func _refresh() -> void:
	if not is_node_ready() or profile == null:
		return
	for row in _rows:
		row.free()
	_rows.clear()
	var count := ceili(float(ORDER.size()) / PAGE_SIZE)
	$BG/HBoxContainer/PageInfor.text = "%d/%d" % [_page + 1, count]
	$BG/HBoxContainer/Last.disabled = _page == 0
	$BG/HBoxContainer/Next.disabled = _page == count - 1
	for index in range(_page * PAGE_SIZE, mini(ORDER.size(), (_page + 1) * PAGE_SIZE)):
		var id: StringName = ORDER[index]
		var data: Dictionary = _presentation.get(String(id), {})
		var row := load("res://Scene/UI/MagicWeaponChoice.tscn").instantiate() as Node2D
		row.position = Vector2(0, -110 + (index % PAGE_SIZE) * 120)
		$BG.add_child(row)
		_rows.append(row)
		var best: ItemInstance
		var has_wood := false
		for uid: StringName in profile.inventory.item_ids():
			var item := profile.inventory.get_item(uid)
			if item.definition_id == id:
				has_wood = has_wood or item.elements.has("木")
				if best == null or item.enhancement > best.enhancement:
					best = item
		var selected := profile.inventory.get_item(profile.battle_relic)
		row.get_node("BG/SkillIcon").texture = load(data.icon) if data.has("icon") else null
		row.get_node("BG/SkillIcon/Name_").text = data.get("name", String(id))
		row.get_node("BG/SkillName").text = data.get("skill", "")
		row.get_node("BG/SkillName/Level").text = "Lv: %d" % (best.enhancement if best != null else 0)
		row.get_node("BG/Skill_Infor").text = data.get("description", "")
		row.get_node("BG/SkillIcon/MU").visible = has_wood
		row.get_node("BG/NoHave").visible = best == null
		row.get_node("BG/isChoose").visible = selected != null and selected.definition_id == id
		row.get_node("BG/choose").disabled = best == null
		if best != null:
			row.get_node("BG/choose").pressed.connect(_select.bind(best.uid))
func _select(uid: StringName) -> void:
	if profile.select_battle_relic(uid):
		changed.emit()
		_refresh()
func _on_last_pressed() -> void:
	_page = maxi(0, _page - 1)
	_refresh()
func _on_next_pressed() -> void:
	_page = mini(ceili(float(ORDER.size()) / PAGE_SIZE) - 1, _page + 1)
	_refresh()
func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
