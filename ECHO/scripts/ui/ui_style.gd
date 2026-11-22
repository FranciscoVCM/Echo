class_name UiStyle
extends RefCounted
## Shared look for menus.

static func button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 46)
	button.add_theme_font_size_override("font_size", 19)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.11, 0.15, 0.85)
	normal.border_color = Color(0.45, 0.45, 0.6, 0.6)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(23)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.2, 0.2, 0.3, 0.95)
	hover.border_color = Color(0.85, 0.85, 1.0, 0.9)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", hover)
	return button


static func panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.045, 0.06, 0.94)
	style.border_color = Color(0.4, 0.4, 0.55, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	return style


static func title(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	return label
