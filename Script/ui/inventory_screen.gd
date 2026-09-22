class_name InventoryScreen
extends Node2D

signal closed

const PAGE_SIZE: int = 35
const ICON_DIRECTORY := "res://assets/Art/BackPack/AllItems/"
const SLOT_ICONS := {&"weapon": "wq", &"armor": "fj", &"accessory": "sp", &"relic": "fb", &"title": "tx", &"costume": "sz", &"wings": "cb"}
const DETAILS_SCENE := preload("res://Scene/UI/InventoryDetails.tscn")
const ACTIONS_SCENE := preload("res://Scene/UI/InventoryActions.tscn")
const STAT_FIELDS := [
	["hp", "Hp_tt"], ["mp", "Mp_tt"], ["att", "Att_tt"], ["def", "Def_tt"], ["lucky", "Lucky_tt"],
	["mdef", "Mdef_tt"], ["crit", "Crit_tt"], ["miss", "misstt"], ["ehp", "ehp_tt"], ["emp", "emp_tt"],
]
const STAT_PAGES := [
	[[&"max_hp", "生命"], [&"max_mp", "魔法"], [&"attack", "攻击"], [&"defense", "物防"], [&"luck", "幸运"], [&"magic_defense", "魔防"], [&"critical_chance", "暴击"], [&"dodge_chance", "闪避"], [&"hp_regen", "回血"], [&"mp_regen", "回魔"]],
	[[&"accuracy", "命中"], [&"toughness", "韧性"], [&"lifesteal", "吸血"], [&"critical_reduction", "暴免"], [&"armor_penetration", "破甲"], [&"magic_penetration", "破魔"]],
]

var profile: PlayerProfile
var actor: CombatActor
var _page: int = 0
var _category: int = 0
var _stats_page: int = 0
var _selected: StringName
var _ids: Array[StringName] = []
var _cells: Array[Button] = []
var _equipment_slots: Dictionary = {}
var _refresh_queued: bool = false
var _details: InventoryItemDetails
var _actions: InventoryItemActions

@onready var _grid: GridContainer = $Main_Backpack/MarginContainer/VBoxContainer/MarginContainer/Sc_Box/Gd_Box
@onready var _last_page: TextureButton = $Main_Backpack/ChangePage/LastPage
@onready var _next_page: TextureButton = $Main_Backpack/ChangePage/NextPage
@onready var _page_text: Label = $Main_Backpack/ChangePage/CurrentPageText
@onready var _coin_text: Label = $Main_Backpack/coin_text/coin_number
@onready var _title: Label = $Main_Backpack/MarginContainer/VBoxContainer/title

func _ready() -> void:
	$Main_Backpack/Timer.stop()
	$background/close.pressed.connect(closed.emit)
	_last_page.pressed.connect(_turn_page.bind(-1))
	_next_page.pressed.connect(_turn_page.bind(1))
	$background/infomation/first.pressed.connect(_set_stats_page.bind(0))
	$background/infomation/second.pressed.connect(_set_stats_page.bind(1))
	var categories := $Main_Backpack/MarginContainer/VBoxContainer/HBoxContainer
	categories.get_node("zb").pressed.connect(_set_category.bind(0))
	categories.get_node("dj").pressed.connect(_set_category.bind(1))
	categories.get_node("xhp").pressed.connect(_set_category.bind(2))
	categories.get_node("pl_sell").disabled = true
	categories.get_node("pl_sell").tooltip_text = "批量出售尚未接入"
	for index in range(_grid.get_child_count()):
		var cell := _grid.get_child(index) as Button
		_cells.append(cell)
		cell.pressed.connect(_select_cell.bind(index))
		cell.mouse_entered.connect(_hover_cell.bind(index))
		cell.mouse_exited.connect(_hide_details)
		cell.get_node("item_number").mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equipment_slots = {
		&"weapon": $background/infomation/equ_/HBoxContainer/wq,
		&"armor": $background/infomation/equ_/HBoxContainer/fj,
		&"accessory": $background/infomation/equ_/VBoxContainer/sp,
		&"relic": $background/infomation/equ_/VBoxContainer/fb,
		&"title": $background/infomation/tx, &"costume": $background/infomation/sz, &"wings": $background/infomation/cb,
	}
	for slot: StringName in _equipment_slots:
		_equipment_slots[slot].pressed.connect(_unequip.bind(slot))
		_equipment_slots[slot].mouse_entered.connect(_hover_equipped.bind(slot))
		_equipment_slots[slot].mouse_exited.connect(_hide_details)
	for node_name in ["WingsShow", "HeadShow"]:
		$background/infomation.get_node(node_name).disabled = true
		$background/infomation.get_node(node_name).tooltip_text = "外观显示偏好存档待迁移"
	$background/Zdlnc/name.editable = false
	$background/gy.self_modulate = Color(1, 1, 1, 0.5)
	if profile == null:
		return
	profile.inventory.changed.connect(_request_refresh)
	profile.progression.changed.connect(_request_refresh)
	if profile.equipment != null:
		profile.equipment.changed.connect(_request_refresh)
	if is_instance_valid(actor):
		actor.combatant.stats.changed.connect(_request_refresh)
	refresh()

func _request_refresh(_changed_id: StringName = &"") -> void:
	if not _refresh_queued:
		_refresh_queued = true
		refresh.call_deferred()

func refresh() -> void:
	_refresh_queued = false
	if profile == null or not is_inside_tree():
		return
	var equipped_ids: Array[StringName] = []
	for slot: StringName in _equipment_slots:
		var equipped := profile.equipment.equipped(slot) if profile.equipment != null else null
		if equipped != null:
			equipped_ids.append(equipped.uid)
	_ids.clear()
	for uid: StringName in profile.inventory.item_ids():
		if equipped_ids.has(uid):
			continue
		var item := profile.inventory.get_item(uid)
		var definition := profile.catalog.get_definition(item.definition_id)
		var category := 0 if not definition.slot().is_empty() else (2 if definition.metadata().get("类型") == "消耗品" else 1)
		if category == _category:
			_ids.append(uid)
	var pages := maxi(1, ceili(float(_ids.size()) / PAGE_SIZE))
	_page = clampi(_page, 0, pages - 1)
	_title.text = ["装备背包", "道具背包", "消耗品背包"][_category]
	_page_text.text = "%d/%d" % [_page + 1, pages]
	_coin_text.text = str(profile.progression.gold)
	for index in range(_cells.size()):
		_update_cell(_cells[index], _page * PAGE_SIZE + index)
	_update_equipment()
	_update_character()
	_update_preview()
	if is_instance_valid(_details):
		_details.refresh()

func _update_cell(cell: Button, item_index: int) -> void:
	cell.icon = load(ICON_DIRECTORY + "empty.png")
	cell.get_node("item_number").text = ""
	if item_index >= _ids.size():
		return
	var item := profile.inventory.get_item(_ids[item_index])
	cell.icon = _item_icon(item, profile.catalog.get_definition(item.definition_id).slot())

func _item_icon(item: ItemInstance, slot: StringName) -> Texture2D:
	var path := ICON_DIRECTORY + String(item.definition_id) + ".png"
	if not ResourceLoader.exists(path):
		path = ICON_DIRECTORY + SLOT_ICONS.get(slot, "empty") + ".png"
	return load(path) as Texture2D

func _update_equipment() -> void:
	for slot: StringName in _equipment_slots:
		var item := profile.equipment.equipped(slot) if profile.equipment != null else null
		_equipment_slots[slot].icon = _item_icon(item, slot) if item != null else load(ICON_DIRECTORY + SLOT_ICONS[slot] + ".png")

func _update_character() -> void:
	var digits := str(profile.progression.level)
	var level_nodes := $background/infomation/leve_background/Level_Show
	level_nodes.position = Vector2(-15, -15) if digits.length() == 1 else Vector2(-35, -15)
	level_nodes.get_node("Number_1").texture = load("res://assets/Art/AllNumber/Level/Level_%s.png" % digits[0])
	level_nodes.get_node("Number_2").texture = load("res://assets/Art/AllNumber/Level/Level_%s.png" % digits[1]) if digits.length() > 1 else null
	var bar := $background/infomation/exp_bar as TextureProgressBar
	bar.value = float(profile.progression.experience) / profile.progression.required_experience()
	bar.get_node("exp_text").text = "%d/%d" % [profile.progression.experience, profile.progression.required_experience()]
	var names := {&"tang_sanzang": "唐僧", &"hero_1": "孙悟空", &"hero_2": "唐僧", &"hero_3": "猪八戒", &"hero_4": "沙僧", &"hero_5": "小白龙"}
	$background/Zdlnc/name.text = names.get(profile.selected_skin, "角色")
	if not is_instance_valid(actor):
		return
	for index in range(STAT_FIELDS.size()):
		var label := get_node("background/infomation/" + STAT_FIELDS[index][0]) as Label
		var title := label.get_node(STAT_FIELDS[index][1]) as Label
		if index >= STAT_PAGES[_stats_page].size():
			label.text = ""
			title.text = ""
			continue
		var field: Array = STAT_PAGES[_stats_page][index]
		var stat: StringName = field[0]
		var amount := actor.combatant.stats.value(stat)
		title.text = field[1]
		label.text = "%.1f%%" % (amount * 100.0) if stat in InventoryItemDetails.PERCENT_STATS else str(snappedf(amount, 0.01))
		if _stats_page == 0 and index == 0:
			label.text = "%d/%d" % [actor.combatant.health.current, actor.combatant.health.maximum]
		elif _stats_page == 0 and index == 1:
			label.text = "%d/%d" % [actor.abilities.mp, actor.abilities.maximum_mp]

func _update_preview() -> void:
	var role := 2 if profile.selected_skin == &"tang_sanzang" else clampi(int(String(profile.selected_skin).trim_prefix("hero_")), 1, 5)
	var body_item := profile.equipment.equipped(&"costume") if profile.equipment != null else null
	if body_item == null and profile.equipment != null:
		body_item = profile.equipment.equipped(&"armor")
	var weapon := profile.equipment.equipped(&"weapon") if profile.equipment != null else null
	$background/RoleBody.texture = _appearance(role, "Body", body_item)
	$background/RoleEquipment.texture = _appearance(role, "Eq", weapon)
	var animation := "wait" if role == 1 else "wait%d" % role
	if $background/Player.current_animation != animation:
		$background/Player.play(animation)
	var wings := profile.equipment.equipped(&"wings") if profile.equipment != null else null
	$background/Wings.visible = wings != null and $background/Wings.sprite_frames.has_animation(wings.definition_id)
	if $background/Wings.visible:
		$background/Wings.play(wings.definition_id)
	else:
		$background/Wings.play("empty")

func _appearance(role: int, part: String, item: ItemInstance) -> Texture2D:
	var prefix := "res://assets/Art/HeroPicture/Role%dAllEquipment/Role_%d_%s_" % [role, role, part]
	var path := prefix + (String(item.definition_id) if item != null else "Empty") + ".png"
	if not ResourceLoader.exists(path):
		path = prefix + "Empty.png"
	return load(path) as Texture2D

func _hover_cell(index: int) -> void:
	var item_index := _page * PAGE_SIZE + index
	if item_index < _ids.size():
		_show_details(_ids[item_index])

func _hover_equipped(slot: StringName) -> void:
	var item := profile.equipment.equipped(slot) if profile.equipment != null else null
	if item != null:
		_show_details(item.uid)

func _show_details(uid: StringName) -> void:
	_hide_details()
	var item := profile.inventory.get_item(uid)
	if item == null:
		return
	_details = DETAILS_SCENE.instantiate()
	_details.profile = profile
	_details.item = item
	_details.z_index = 199
	add_child(_details)

func _hide_details() -> void:
	if is_instance_valid(_details):
		_details.queue_free()
	_details = null

func _select_cell(index: int) -> void:
	var item_index := _page * PAGE_SIZE + index
	if item_index < _ids.size():
		_select(_ids[item_index])

func _select(uid: StringName) -> void:
	_selected = uid
	var item := profile.inventory.get_item(uid)
	if item == null:
		return
	if is_instance_valid(_actions):
		_actions.queue_free()
	var metadata := profile.catalog.get_definition(item.definition_id).metadata()
	if profile.catalog.get_definition(item.definition_id).slot().is_empty():
		return
	_actions = ACTIONS_SCENE.instantiate()
	_actions.z_index = 99
	_actions.uid = uid
	_actions.page = _page + 1
	_actions.cell_number = _ids.find(uid) % PAGE_SIZE + 1
	_actions.allow_sell = item.enhancement == 0 and item.gems.is_empty() and metadata.get("类型") != "法宝" and metadata.get("品质") not in ["传说", "玄冥", "魂器", "神器", "邪灵"]
	_actions.equip_requested.connect(_equip)
	_actions.sell_requested.connect(_sell)
	$Main_Backpack.add_child(_actions)
	_actions.position = get_viewport().get_mouse_position() - Vector2(640, 280)

func _equip(uid: StringName) -> void:
	if profile.equipment != null:
		profile.equipment.equip(uid)
	refresh()

func _unequip(slot: StringName) -> void:
	if profile.equipment != null:
		profile.equipment.unequip(slot)
	_hide_details()
	refresh()

func _sell(uid: StringName) -> void:
	var economy := ItemEconomy.new(profile.inventory, profile.progression)
	economy.sell(uid)
	_hide_details()
	refresh()

func _enhance() -> bool:
	var item := profile.inventory.get_item(_selected)
	if item == null or profile.catalog.get_definition(item.definition_id).slot().is_empty():
		return false
	var cost := (item.enhancement + 1) * 25
	if item.enhancement >= 20 or profile.progression.gold < cost:
		return false
	if not profile.inventory.enhance(item.uid, item.enhancement + 1):
		return false
	profile.progression.spend(cost)
	refresh()
	return true

func _turn_page(direction: int) -> void:
	_page += direction
	_hide_details()
	refresh()

func _set_category(category: int) -> void:
	_category = category
	_page = 0
	_hide_details()
	refresh()

func _set_stats_page(page: int) -> void:
	_stats_page = page
	_update_character()
