class_name PauseMenu
extends CanvasLayer
## Escape menu. Pauses the scene tree while open.

signal resume_requested
signal restart_requested
signal menu_requested

var is_open: bool = false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := PanelContainer.new()
	UiTheme.place(panel, Vector2(0.5, 0.5), Rect2(-170, -170, 340, 340))
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := UiTheme.make_label("Paused", 28, InkStyle.PAPER, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(HSeparator.new())
	box.add_child(UiTheme.make_button("Resume", func() -> void: resume_requested.emit()))
	box.add_child(UiTheme.make_button("Restart Investigation", func() -> void: restart_requested.emit()))
	box.add_child(UiTheme.make_button("Abandon to Main Menu", func() -> void: menu_requested.emit()))
	box.add_child(UiTheme.make_button("Quit Game", func() -> void: GameManager.quit_game()))
	var hint := UiTheme.make_label("WASD move · Mouse aim · E interact · F use · G drop\n1-4 equipment · Shift sprint · J journal", 12, InkStyle.PAPER_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	is_open = true
	visible = true
	get_tree().paused = true


func close() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
