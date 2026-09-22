class_name GameHUD
extends Control
## 只绑定旧 HUD 的可编辑节点；技能显示消费授予列表，不自行授予技能。

signal inventory_requested
signal quests_requested
signal pause_requested
signal settings_requested
signal skill_requested
signal magic_weapon_requested
signal pet_requested

const LAYER := "RoleInformation/roleLayer/"
const STATUS := LAYER + "role_hp_mp_exp/"
const MENU := LAYER + "role_menu/"
const EMPTY_ICON := preload("res://assets/Art/Skill/LittleSkillIcon/Empty.png")
const SLOT_NAMES: Array[String] = ["Y", "U", "I", "O", "L"]

var actor: CombatActor
var progression: PlayerProgression
var _skills: Array[StringName] = []
var _skill_categories: Array[StringName] = []
var _slots: Array[TextureRect] = []
var _relic_skill: StringName = &""
var _elapsed: float = 0.0

@onready var _hp: TextureProgressBar = get_node(STATUS + "hp_bar")
@onready var _mp: TextureProgressBar = get_node(STATUS + "mp_bar")
@onready var _exp: TextureProgressBar = get_node(STATUS + "exp_bar")
@onready var _hp_text: Label = get_node(STATUS + "hp_bar/hp_text")
@onready var _mp_text: Label = get_node(STATUS + "mp_bar/mp_text")
@onready var _level: Label = get_node(STATUS + "role_level")

func _ready() -> void:
	_ignore_pointer_input($RoleInformation)
	for slot_name: String in SLOT_NAMES:
		var slot := get_node(MENU + "SkillBox/" + slot_name) as TextureRect
		slot.gui_input.connect(_on_skill_input.bind(_slots.size()))
		_slots.append(slot)
		_skills.append(&"")
		_skill_categories.append(&"")
	_set_button("backpack", inventory_requested.emit, "背包 B")
	_set_button("set", settings_requested.emit, "游戏设置")
	_set_button("skill", skill_requested.emit, "技能学习")
	_set_button("magic_weapon", magic_weapon_requested.emit, "法宝")
	_set_button("pet", pet_requested.emit, "宠物")
	get_node(LAYER + "Gogo").hide()
	get_node(STATUS + "RoleProtect").hide()
	get_node(MENU + "SkillBox/MagicWeaponSkillCD").tooltip_text = "实战法宝 H"
	get_node(MENU + "SkillBox2/ZhenFa").tooltip_text = "阵法系统尚未迁移"
	var relic_slot: Control = get_node(MENU + "SkillBox/MagicWeaponSkillCD")
	relic_slot.mouse_filter = Control.MOUSE_FILTER_STOP
	relic_slot.gui_input.connect(_relic_input)
	_refresh_skills()

func _relic_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _relic_skill.is_empty() and not get_tree().paused:
		actor.use_ability(_relic_skill, &"magic_weapon")

func _ignore_pointer_input(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_pointer_input(child)

func _set_button(name: String, callback: Callable, tooltip: String) -> void:
	var button := get_node(MENU + name) as TextureButton
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.tooltip_text = tooltip
	button.pressed.connect(callback)

func bind(player: CombatActor, data: PlayerProgression, _area_name: String) -> void:
	_unbind()
	actor = player
	progression = data
	actor.combatant.health.changed.connect(_health_changed)
	actor.abilities.mana_changed.connect(_mana_changed)
	actor.abilities.grants_changed.connect(_refresh_skills)
	progression.changed.connect(_progress_changed)
	_health_changed(actor.combatant.health.current, actor.combatant.health.maximum)
	_mana_changed(actor.abilities.mp, actor.abilities.maximum_mp)
	_progress_changed()
	var view := actor.get_node_or_null("ActorView") as ActorView
	if view != null:
		var portraits := {&"tang_sanzang": "tsz", &"hero_1": "swk", &"hero_2": "tsz", &"hero_3": "zbj", &"hero_4": "shs", &"hero_5": "blm"}
		var portrait: String = portraits.get(view.skin_id, "")
		if not portrait.is_empty():
			get_node(LAYER + "role_head").texture = load("res://assets/Art/HeroPicture/RoleProperiesBox/%s.png" % portrait)
	_refresh_skills()

func _unbind() -> void:
	if is_instance_valid(actor):
		actor.combatant.health.changed.disconnect(_health_changed)
		actor.abilities.mana_changed.disconnect(_mana_changed)
		actor.abilities.grants_changed.disconnect(_refresh_skills)
	if progression != null:
		progression.changed.disconnect(_progress_changed)

func _refresh_skills() -> void:
	for index in range(_slots.size()):
		_skills[index] = &""
		_skill_categories[index] = &""
		var slot := _slots[index]
		slot.texture = EMPTY_ICON
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.tooltip_text = "未配置技能"
		slot.get_node("Y").text = ""
		slot.get_node("TimeText").text = ""
		slot.get_node("PicBox").texture_progress = null
		slot.get_node("PicBox").value = 0.0
	if not is_instance_valid(actor):
		return
	var keys: Dictionary = {}
	var input := actor.get_node_or_null("PlayerInput")
	if input != null and input.source is ActionInputSource:
		for action_name: StringName in input.source.slots:
			for event: InputEvent in InputMap.action_get_events(action_name):
				if event is InputEventKey:
					keys[input.source.slots[action_name]] = OS.get_keycode_string(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
					break
	_relic_skill = input.source.slots.get(&"magic_weapon", &"") if input != null and input.source is ActionInputSource else &""
	var relic_slot := get_node(MENU + "SkillBox/MagicWeaponSkillCD")
	relic_slot.get_node("skillicon").texture = null
	if not _relic_skill.is_empty():
		var relic_definition := actor.abilities.get_definition(_relic_skill)
		if relic_definition != null:
			relic_slot.tooltip_text = relic_definition.display_name
			var relic_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/combat/relic_presentation.json"))
			for item_id: String in relic_data:
				if RelicAbilityRegistry.ITEM_TO_ABILITY.get(StringName(item_id)) == _relic_skill:
					var data: Dictionary = relic_data[item_id]
					relic_slot.tooltip_text = data.get("skill", "")
					var texture: Texture2D = load(data.icon) if data.has("icon") else null
					relic_slot.get_node("skillicon").texture = texture
					relic_slot.get_node("PicBox").texture_progress = texture

	var pending: Array = []
	for id: StringName in actor.abilities.granted_ids():
		var definition := actor.abilities.get_definition(id)
		if definition != null and (definition.passive or actor.abilities.has_category(id, &"magic_weapon")):
			continue
		var index := SLOT_NAMES.find(String(keys.get(id, "")))
		if index >= 0 and _skills[index].is_empty():
			_fill_slot(index, id, keys[id])
		else:
			pending.append(id)
	for id: StringName in pending:
		var index := _skills.find(&"")
		if index < 0:
			break
		_fill_slot(index, id, String(keys.get(id, "")))

func _fill_slot(index: int, id: StringName, key: String) -> void:
	var definition := actor.abilities.get_definition(id)
	var grant := actor.abilities.get_grant(id)
	var slot := _slots[index]
	_skills[index] = id
	_skill_categories[index] = grant.category if grant != null else &"character"
	var icon_id := definition.legacy_id if not definition.legacy_id.is_empty() else definition.animation
	var icon_path := "res://assets/Art/Skill/LittleSkillIcon/%s.png" % icon_id
	if not icon_id.is_empty() and ResourceLoader.exists(icon_path):
		slot.texture = load(icon_path)
	slot.get_node("PicBox").texture_progress = slot.texture
	slot.get_node("Y").text = key
	var category_label := ""
	if grant != null and grant.category == &"magic_weapon":
		category_label = "【法宝】"
	elif grant != null and grant.category == &"equipment":
		category_label = "【装备】"
	slot.tooltip_text = category_label + (definition.display_name if not definition.display_name.is_empty() else String(id))
	if definition.migration_status == "metadata_only":
		slot.tooltip_text += "（效果尚未迁移）"
	else:
		slot.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_skill_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_request_skill(_skills[index])
		_slots[index].accept_event()

func _health_changed(current: float, maximum: float) -> void:
	_hp.max_value = maximum
	_hp.value = current
	_hp_text.text = "%.0f / %.0f" % [current, maximum]
	var trail := get_node(STATUS + "hp_bar/hp_bar2") as TextureProgressBar
	trail.max_value = maximum
	trail.value = current

func _mana_changed(current: float, maximum: float) -> void:
	_mp.max_value = maximum
	_mp.value = current
	_mp_text.text = "%.0f / %.0f" % [current, maximum]

func _progress_changed() -> void:
	_level.text = str(progression.level)
	_exp.max_value = progression.required_experience()
	_exp.value = progression.experience
	get_node(STATUS + "exp_bar/exp_text").text = "%.0f / %.0f" % [_exp.value, _exp.max_value]

func notify(text: String, duration: float = 3.0) -> void:
	GameNotification.show_message(self, text, duration)

func _request_skill(id: StringName) -> void:
	if not id.is_empty() and is_instance_valid(actor) and not get_tree().paused:
		actor.use_ability(id, _skill_categories[_skills.find(id)])

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.1 or not is_instance_valid(actor):
		return
	_elapsed = 0.0
	if not _relic_skill.is_empty():
		var relic_slot := get_node(MENU + "SkillBox/MagicWeaponSkillCD")
		var remaining := actor.abilities.remaining_cooldown(_relic_skill)
		var definition := actor.abilities.get_definition(_relic_skill)
		relic_slot.get_node("TimeText").text = "%.1f" % remaining if remaining > 0 else ""
		relic_slot.get_node("PicBox").value = remaining / definition.cooldown if definition != null and definition.cooldown > 0 else 0
	for index in range(_skills.size()):
		if _skills[index].is_empty():
			continue
		var remaining := actor.abilities.remaining_cooldown(_skills[index])
		var definition := actor.abilities.get_definition(_skills[index])
		_slots[index].get_node("TimeText").text = "%.1f" % remaining if remaining > 0.0 else ""
		_slots[index].get_node("PicBox").value = remaining / definition.cooldown if definition != null and definition.cooldown > 0.0 else 0.0

func _exit_tree() -> void:
	_unbind()
