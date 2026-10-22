class_name DeathScreen
extends CanvasLayer
## Shown after the ghost catches the investigator.

signal continue_requested
signal restart_requested

var _root: Control
var _fade: ColorRect
var _content: VBoxContainer
var _t: float = -1.0


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.01, 0.01, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_fade)
	_content = VBoxContainer.new()
	UiTheme.place(_content, Vector2(0.5, 0.5), Rect2(-260, -120, 520, 240))
	_content.add_theme_constant_override("separation", 14)
	_content.modulate.a = 0.0
	_root.add_child(_content)
	var title := UiTheme.make_label("You were taken.", 40, Color(0.78, 0.70, 0.62), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)
	var sub := UiTheme.make_label("The house keeps what it catches.", 17, InkStyle.PAPER_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(sub)
	_content.add_child(UiTheme.make_button("Read the Case File", func() -> void: continue_requested.emit()))
	_content.add_child(UiTheme.make_button("Restart Investigation", func() -> void: restart_requested.emit()))


func show_screen() -> void:
	visible = true
	_t = 0.0


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	_fade.color.a = clampf(_t / 1.2, 0.0, 0.92)
	_content.modulate.a = clampf((_t - 0.8) / 1.0, 0.0, 1.0)
