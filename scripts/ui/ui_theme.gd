class_name UiTheme
extends RefCounted
## Builds the shared "dark paper and ink" UI theme in code so every screen
## stays consistent. Fonts are system serif faces with safe fallbacks.

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func clear_cache() -> void:
	_theme = null


static func serif_font(bold: bool = false) -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Times New Roman", "DejaVu Serif", "Liberation Serif", "serif"])
	f.font_weight = 700 if bold else 400
	return f


static func panel_style(bg: Color = InkStyle.PAPER_DARK, border: Color = Color(0.42, 0.37, 0.30)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(1)
	sb.set_content_margin_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	return sb


static func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.border_width_bottom = 2
	sb.set_content_margin_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	return sb


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = serif_font()
	t.default_font_size = 17
	var ink_text := InkStyle.PAPER
	t.set_color("font_color", "Label", ink_text)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_color("default_color", "RichTextLabel", ink_text)
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	var normal := _button_style(Color(0.13, 0.115, 0.10), Color(0.38, 0.33, 0.27))
	var hover := _button_style(Color(0.20, 0.175, 0.15), Color(0.62, 0.55, 0.45))
	var pressed := _button_style(Color(0.09, 0.08, 0.07), Color(0.70, 0.62, 0.50))
	var disabled := _button_style(Color(0.10, 0.09, 0.08), Color(0.22, 0.20, 0.17))
	for type in ["Button", "CheckBox", "CheckButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		t.set_color("font_color", type, ink_text)
		t.set_color("font_hover_color", type, Color(0.95, 0.91, 0.82))
		t.set_color("font_pressed_color", type, Color(0.95, 0.91, 0.82))
		t.set_color("font_disabled_color", type, Color(0.45, 0.42, 0.37))
	t.set_stylebox("normal", "CheckBox", _button_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	t.set_stylebox("hover", "CheckBox", _button_style(Color(1, 1, 1, 0.04), Color(0, 0, 0, 0)))
	t.set_stylebox("pressed", "CheckBox", _button_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.07, 0.06)
	bg.border_color = Color(0.38, 0.33, 0.27)
	bg.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.62, 0.57, 0.48)
	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_color("font_color", "ProgressBar", Color(0, 0, 0, 0))
	t.set_stylebox("panel", "TooltipPanel", panel_style(Color(0.1, 0.09, 0.08)))
	t.set_color("font_color", "TooltipLabel", ink_text)
	var sep := StyleBoxLine.new()
	sep.color = Color(0.42, 0.37, 0.30, 0.6)
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	return t


static func make_label(text: String, size: int = 17, color: Color = InkStyle.PAPER, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", serif_font(true))
	return l


static func make_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void:
		AudioManager.play(&"ui_click", -6.0)
		callback.call())
	return b


## Anchors a control to a point of its parent (0..1 on each axis) and places
## it with a pixel rect relative to that point. Robust to window resizing.
static func place(c: Control, anchor: Vector2, rect: Rect2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = rect.position.x
	c.offset_top = rect.position.y
	c.offset_right = rect.end.x
	c.offset_bottom = rect.end.y
	# Content larger than the rect grows away from the anchor point.
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH if anchor.x == 0.5 else (Control.GROW_DIRECTION_BEGIN if anchor.x == 1.0 else Control.GROW_DIRECTION_END)
	c.grow_vertical = Control.GROW_DIRECTION_BOTH if anchor.y == 0.5 else (Control.GROW_DIRECTION_BEGIN if anchor.y == 1.0 else Control.GROW_DIRECTION_END)
