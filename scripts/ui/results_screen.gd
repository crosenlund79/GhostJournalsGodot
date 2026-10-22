class_name ResultsScreen
extends CanvasLayer
## End-of-investigation report.

signal restart_requested
signal menu_requested

var _root: Control
var _body: VBoxContainer
var last_results: Dictionary = {}


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.032, 0.03, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var panel := PanelContainer.new()
	UiTheme.place(panel, Vector2(0.5, 0.5), Rect2(-380, -300, 760, 600))
	var style := UiTheme.panel_style(Color(0.145, 0.128, 0.105), Color(0.48, 0.42, 0.33))
	style.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	var title := UiTheme.make_label("Case File — Hollow Lane House", 28, InkStyle.PAPER, true)
	outer.add_child(title)
	outer.add_child(HSeparator.new())
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 7)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_body)
	outer.add_child(HSeparator.new())
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(buttons)
	buttons.add_child(UiTheme.make_button("New Investigation", func() -> void: restart_requested.emit()))
	buttons.add_child(UiTheme.make_button("Main Menu", func() -> void: menu_requested.emit()))


func show_results(results: Dictionary) -> void:
	last_results = results
	for c in _body.get_children():
		c.queue_free()
	var survived: bool = results.get("survived", false)
	var selected: String = results.get("selected_ghost", "")
	var correct: bool = results.get("correct", false)
	if results.get("tutorial", false):
		_row("Mode", "Training investigation (Learn to Play)", Color(0.82, 0.86, 0.72))
	_row("Outcome", "Survived" if survived else "Did not survive")
	_row("Time on site", results.get("duration", "--:--"))
	_row("The entity was", results.get("actual_ghost", "?"))
	_row("Your conclusion", selected if selected != "" else "No conclusion recorded")
	_row("Identification", "Correct" if correct else ("Incorrect" if selected != "" else "Not attempted"),
		Color(0.80, 0.88, 0.70) if correct else Color(0.85, 0.58, 0.50))
	var ex: StringName = results.get("exorcism", &"not_attempted")
	var ex_text := {&"success": "The entity was banished", &"failed": "The rite failed", &"not_attempted": "Not attempted"}
	_row("Exorcism", ex_text.get(ex, "Not attempted"))
	_row("Evidence detected", _join(results.get("observed_evidence", [])))
	_row("Marked confirmed", _join(results.get("confirmed_evidence", [])))
	_row("Marked ruled out", _join(results.get("ruled_out_evidence", [])))
	_row("Its true evidence", _join(results.get("actual_evidence", [])))
	visible = true


func _join(items: Array) -> String:
	if items.is_empty():
		return "none"
	var parts: PackedStringArray = PackedStringArray()
	for i in items:
		parts.append(str(i))
	return ", ".join(parts)


func _row(label: String, value: String, value_color: Color = InkStyle.PAPER) -> void:
	var row := HBoxContainer.new()
	var l := UiTheme.make_label(label, 16, InkStyle.PAPER_MUTED)
	l.custom_minimum_size = Vector2(220, 0)
	row.add_child(l)
	var v := UiTheme.make_label(value, 17, value_color)
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	_body.add_child(row)
