class_name InventoryItemDetails
extends Node2D

const FIELDS := {
	"eq_hp": [&"max_hp", "生命"], "eq_mp": [&"max_mp", "魔法"], "eq_power": [&"attack", "攻击"],
	"eq_def": [&"defense", "物防"], "eq_mdef": [&"magic_defense", "魔防"], "eq_crit": [&"critical_chance", "暴击"],
	"eq_miss": [&"dodge_chance", "闪避"], "eq_ehp": [&"hp_regen", "回血"], "eq_emp": [&"mp_regen", "回魔"],
	"eq_mz": [&"accuracy", "命中"], "eq_lucky": [&"luck", "幸运"], "eq_rx": [&"toughness", "韧性"],
	"eq_pj": [&"armor_penetration", "破甲"], "eq_pm": [&"magic_penetration", "破魔"],
	"eq_xx": [&"lifesteal", "吸血"], "eq_bm": [&"critical_reduction", "暴免"],
}
const PERCENT_STATS := [&"critical_chance", &"dodge_chance", &"accuracy", &"toughness", &"lifesteal", &"critical_reduction"]

var profile: PlayerProfile
var item: ItemInstance
var item_definition: ItemDefinition
var follow_pointer: bool = true
var maximum_position := Vector2(495, 320)
var horizontal_reposition: float = 270.0

func _ready() -> void:
	for control in find_children("*", "Control", true, false):
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)

func refresh() -> void:
	if item == null and item_definition == null:
		return
	var definition := item_definition if item == null else profile.catalog.get_definition(item.definition_id)
	var metadata := definition.metadata()
	var header := $pro_wk/information/inf/VBoxContainer2
	header.get_node("eq_name").text = str(metadata.get("名字", definition.id)) + ("(+%d)" % item.enhancement if item != null and item.enhancement > 0 else "")
	header.get_node("eq_pz").text = "品质：" + str(metadata.get("品质", ""))
	header.get_node("eq_lx").text = "类型：%s·%s" % [metadata.get("类型", ""), metadata.get("所属", "")]
	var color := Color.from_string("#" + str(metadata.get("颜色", "FFFFFF")), Color.WHITE)
	for node_name in ["eq_name", "eq_pz"]:
		header.get_node(node_name).add_theme_color_override("font_color", color)
		header.get_node(node_name).add_theme_color_override("font_outline_color", color)
	header.get_node("have").visible = item != null and definition.slot().is_empty()
	header.get_node("have").text = "拥有：1 个"
	var properties := $pro_wk/information/inf/VBoxContainer3
	properties.visible = not definition.slot().is_empty()
	properties.get_node("eq_czl").visible = definition.slot() == &"relic"
	properties.get_node("eq_czl").text = "成长率：" + (_range_text(_bounds(metadata.get("成长率", 1))) if item == null else str(item.rolls.get("成长率", metadata.get("成长率", 1))))
	properties.get_node("eq_star_level").visible = definition.slot() == &"relic"
	properties.get_node("eq_star_level").text = "五行：" + ("随机" if item == null else "".join(item.elements))
	if item == null:
		_bind_definition_stats(properties, metadata)
	else:
		_bind_stats(properties, definition.stats(item))
	var gem_stats: Dictionary = {}
	for gem_data: Dictionary in item.gems if item != null else []:
		var gem := ItemInstance.from_data(gem_data)
		var gem_definition := profile.catalog.get_definition(gem.definition_id)
		if gem_definition == null:
			continue
		var values := gem_definition.stats(gem)
		for stat: StringName in values:
			gem_stats[stat] = float(gem_stats.get(stat, 0.0)) + float(values[stat])
	$pro_wk/information/inf/BsProp.visible = item != null and not item.gems.is_empty()
	_bind_stats($pro_wk/information/inf/BsProp, gem_stats)
	var footer := $pro_wk/information/inf/VBoxContainer
	footer.get_node("eq_ms").text = "描述：" + str(metadata.get("描述", ""))
	footer.get_node("eq_ms").visible = not str(metadata.get("描述", "")).is_empty()
	footer.get_node("eq_sj").text = "售价：%d灵魂。" % int(metadata.get("售价", 0))

func _bind_stats(container: VBoxContainer, stats: Dictionary) -> void:
	for field: String in FIELDS:
		var stat: StringName = FIELDS[field][0]
		var amount := float(stats.get(stat, 0.0))
		var label := container.get_node(field) as Label
		label.visible = not is_zero_approx(amount)
		if stat in PERCENT_STATS:
			amount *= 100.0
		label.text = "%s：%s" % [FIELDS[field][1], str(snappedf(amount, 0.01))]

func _process(_delta: float) -> void:
	$ColorRect.size = $pro_wk/information.size
	if follow_pointer:
		position = get_viewport().get_mouse_position() - Vector2(430, 250)
	if position.y + $ColorRect.size.y >= maximum_position.y:
		position.y = maximum_position.y - $ColorRect.size.y
	if position.x + $ColorRect.size.x >= maximum_position.x:
		position.x = horizontal_reposition - $ColorRect.size.x

func _bind_definition_stats(container: VBoxContainer, metadata: Dictionary) -> void:
	for field: String in FIELDS:
		var stat: StringName = FIELDS[field][0]
		var bounds := Vector2.ZERO
		for legacy_key: String in ItemDefinition.STAT_NAMES:
			if ItemDefinition.STAT_NAMES[legacy_key] == stat:
				bounds = _bounds(metadata.get(legacy_key, 0))
				break
		var label := container.get_node(field) as Label
		label.visible = not bounds.is_zero_approx()
		label.text = "%s：%s" % [FIELDS[field][1], _range_text(bounds)]

func _range_text(bounds: Vector2) -> String:
	if is_equal_approx(bounds.x, bounds.y):
		return str(snappedf(bounds.x, 0.01))
	return "%s~%s" % [str(snappedf(bounds.x, 0.01)), str(snappedf(bounds.y, 0.01))]

func _bounds(value: Variant) -> Vector2:
	if not value is Dictionary:
		return Vector2(float(value), float(value))
	if value.has("random"):
		var bounds := Vector2(float(value.min), float(value.max))
		if value.has("step"):
			bounds.x = snappedf(bounds.x, float(value.step))
			bounds.y = snappedf(bounds.y, float(value.step))
		return bounds
	var left := _bounds(value.get("left", 0))
	var right := _bounds(value.get("right", 0))
	match value.get("operation", ""):
		"Add": return Vector2(left.x + right.x, left.y + right.y)
		"Sub": return Vector2(left.x - right.y, left.y - right.x)
		"Mult":
			var products := [left.x * right.x, left.x * right.y, left.y * right.x, left.y * right.y]
			return Vector2(products.min(), products.max())
		"Div":
			if right.x <= 0.0 and right.y >= 0.0:
				return Vector2.ZERO
			var quotients := [left.x / right.x, left.x / right.y, left.y / right.x, left.y / right.y]
			return Vector2(quotients.min(), quotients.max())
	return Vector2.ZERO
