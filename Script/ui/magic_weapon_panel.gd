class_name MagicWeaponPanel
extends Node2D
## 复用原版法宝选择窗口；列表来自背包实例，技能来自 ItemDefinition 注册引用。

signal closed

var profile: PlayerProfile
var actor: CombatActor
var _list: Control
var _relics: Array[StringName] = []
var _page := 0
const PAGE_SIZE := 6

@onready var _page_info: Label = $BG/HBoxContainer/PageInfor
@onready var _last_page: BaseButton = $BG/HBoxContainer/Last
@onready var _next_page: BaseButton = $BG/HBoxContainer/Next

func setup(owner_profile: PlayerProfile, owner_actor: CombatActor) -> void:
	profile = owner_profile
	actor = owner_actor
	_refresh()

func _ready() -> void:
	_refresh()

func _on_last_pressed() -> void:
	_page = maxi(0, _page - 1)
	_refresh()

func _on_next_pressed() -> void:
	_page = mini(maxi(0, ceili(float(_relics.size()) / PAGE_SIZE) - 1), _page + 1)
	_refresh()

func _on_close_pressed() -> void:
	closed.emit()
	queue_free()

func _refresh() -> void:
	if not is_node_ready() or profile == null:
		return
	if is_instance_valid(_list):
		_list.queue_free()
	_relics.clear()
	for uid: StringName in profile.inventory.item_ids():
		var item := profile.inventory.get_item(uid)
		var definition := profile.catalog.get_definition(item.definition_id) if item != null else null
		if definition != null and definition.slot() == &"relic":
			_relics.append(uid)
	_page = clampi(_page, 0, maxi(0, ceili(float(_relics.size()) / PAGE_SIZE) - 1))
	_list = Control.new()
	_list.name = "RelicList"
	_list.position = Vector2(-330, -155)
	_list.size = Vector2(650, 330)
	$BG.add_child(_list)
	var row := 0
	var first := _page * PAGE_SIZE
	var last := mini(first + PAGE_SIZE, _relics.size())
	for index in range(first, last):
		var uid: StringName = _relics[index]
		var item := profile.inventory.get_item(uid)
		var definition := profile.catalog.get_definition(item.definition_id) if item != null else null
		if definition == null or definition.slot() != &"relic":
			continue
		_add_relic_row(uid, item, definition, row)
		row += 1
	if row == 0:
		_add_label("尚未获得法宝", Vector2(220, 145), 22)
	var page_count := maxi(1, ceili(float(_relics.size()) / PAGE_SIZE))
	_page_info.text = "%d/%d" % [_page + 1, page_count]
	_last_page.disabled = _page <= 0
	_next_page.disabled = _page >= page_count - 1

func _add_relic_row(uid: StringName, item: ItemInstance, definition: ItemDefinition, row: int) -> void:
	var y := float(row * 50)
	var name := _add_label(str(definition.metadata().get("名字", definition.id)), Vector2(10, y), 20)
	name.size = Vector2(150, 34)
	var ability_names: Array[String] = []
	for ability_id: String in definition.skill_ids():
		var ability := profile.content.resolve_ability(StringName(ability_id))
		ability_names.append(ability.display_name if ability != null and not ability.display_name.is_empty() else ability_id)
	var info := _add_label("技能：%s" % ", ".join(ability_names), Vector2(170, y + 2), 15)
	info.size = Vector2(310, 32)
	var button := Button.new()
	button.text = "已装备" if profile.equipment != null and profile.equipment.equipped(&"relic") == item else "装备"
	button.position = Vector2(500, y)
	button.size = Vector2(90, 32)
	button.pressed.connect(_equip.bind(uid))
	_list.add_child(button)

func _equip(uid: StringName) -> void:
	if profile.equipment != null and profile.equipment.equip(uid):
		_refresh()

func _add_label(text: String, position: Vector2, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	_list.add_child(label)
	return label
