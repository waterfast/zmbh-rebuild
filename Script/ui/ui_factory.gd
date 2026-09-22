class_name GameUI
extends RefCounted

static func label(parent: Node, text: String, position: Vector2, font_size: int = 18, color: Color = Color.WHITE) -> Label:
	var result := Label.new()
	result.text = text
	result.position = position
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	result.add_theme_constant_override("shadow_offset_x", 1)
	result.add_theme_constant_override("shadow_offset_y", 1)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

static func button(parent: Node, text: String, rect: Rect2, callback: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.position = rect.position
	result.size = rect.size
	result.focus_mode = Control.FOCUS_NONE
	result.add_theme_font_size_override("font_size", 19)
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

static func texture(parent: Node, path: String, position: Vector2, size: Vector2 = Vector2.ZERO) -> TextureRect:
	var result := TextureRect.new()
	result.texture = load(path)
	result.position = position
	if size != Vector2.ZERO:
		result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		result.size = size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

static func panel(parent: Node, rect: Rect2) -> Panel:
	var result := Panel.new()
	result.position = rect.position
	result.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.05, 0.92)
	style.border_color = Color(0.63, 0.46, 0.23)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	result.add_theme_stylebox_override("panel", style)
	parent.add_child(result)
	return result
