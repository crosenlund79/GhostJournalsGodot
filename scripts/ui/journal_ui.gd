class_name JournalUI
extends CanvasLayer
## The case journal (J). Evidence marks with three states, field notes from
## genuine observations, the filtered list of possible entities and the
## player's final conclusion. Never reveals whether the conclusion is right.

signal opened
signal closed

const MARK_PREFIX := ["[  ]", "[ + ]", "[ – ]"]
const MARK_WORD := ["", "confirmed", "ruled out"]

var investigation: InvestigationManager
var is_open: bool = false

var _root: Control
var _evidence_buttons: Dictionary = {}
var _ghost_buttons: Dictionary = {}
var _ghost_details: Dictionary = {}
var _notes_box: VBoxContainer
var _conclusion: Label
var _time_label: Label


func _ready() -> void:
	layer = 20
	visible = false


func setup(manager: InvestigationManager) -> void:
	investigation = manager
	_build()
	investigation.journal_changed.connect(refresh)
	refresh()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	UiTheme.place(panel, Vector2(0.5, 0.5), Rect2(-500, -310, 1000, 620))
	var style := UiTheme.panel_style(Color(0.145, 0.128, 0.105), Color(0.48, 0.42, 0.33))
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	var title := UiTheme.make_label("Case Journal — Hollow Lane House", 26, InkStyle.PAPER, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_time_label = UiTheme.make_label("", 15, InkStyle.PAPER_MUTED)
	header.add_child(_time_label)
	outer.add_child(HSeparator.new())

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 26)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(columns)

	# Evidence column.
	var ev_col := VBoxContainer.new()
	ev_col.custom_minimum_size = Vector2(285, 0)
	columns.add_child(ev_col)
	ev_col.add_child(UiTheme.make_label("Evidence", 20, InkStyle.PAPER, true))
	var ev_hint := UiTheme.make_label("Click to cycle: unknown → confirmed → ruled out", 12, InkStyle.PAPER_MUTED)
	ev_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ev_col.add_child(ev_hint)
	for e in investigation.database.evidence:
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = "%s\n\n%s" % [e.description, e.discovery_requirements]
		var eid := e.id
		b.pressed.connect(func() -> void:
			AudioManager.play(&"ui_page", -8.0)
			investigation.cycle_mark(eid))
		ev_col.add_child(b)
		_evidence_buttons[e.id] = b

	# Field notes column.
	var notes_col := VBoxContainer.new()
	notes_col.custom_minimum_size = Vector2(300, 0)
	notes_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(notes_col)
	notes_col.add_child(UiTheme.make_label("Field Notes", 20, InkStyle.PAPER, true))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	notes_col.add_child(scroll)
	_notes_box = VBoxContainer.new()
	_notes_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notes_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_notes_box)

	# Entities column.
	var gh_col := VBoxContainer.new()
	gh_col.custom_minimum_size = Vector2(310, 0)
	gh_col.add_theme_constant_override("separation", 6)
	columns.add_child(gh_col)
	gh_col.add_child(UiTheme.make_label("Possible Entities", 20, InkStyle.PAPER, true))
	for g in investigation.database.ghosts:
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var gid := g.id
		b.pressed.connect(func() -> void:
			AudioManager.play(&"ui_click", -6.0)
			investigation.select_ghost(gid))
		gh_col.add_child(b)
		_ghost_buttons[g.id] = b
		var details := UiTheme.make_label("", 13, InkStyle.PAPER_MUTED)
		details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.custom_minimum_size = Vector2(300, 0)
		gh_col.add_child(details)
		_ghost_details[g.id] = details
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gh_col.add_child(spacer)
	_conclusion = UiTheme.make_label("", 15, InkStyle.PAPER)
	_conclusion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_conclusion.custom_minimum_size = Vector2(300, 0)
	gh_col.add_child(_conclusion)

	outer.add_child(HSeparator.new())
	var footer := UiTheme.make_label("J / Esc — close the journal.  Your conclusion is judged when you leave the house.", 13, InkStyle.PAPER_MUTED)
	outer.add_child(footer)


func refresh() -> void:
	if investigation == null or _root == null:
		return
	_time_label.text = "time on site  %s" % investigation.time_string()
	for e in investigation.database.evidence:
		var b: Button = _evidence_buttons[e.id]
		var mark := investigation.get_mark(e.id)
		b.text = "%s  %s" % [MARK_PREFIX[mark], e.display_name]
		var col := InkStyle.PAPER
		if mark == JournalLogic.Mark.CONFIRMED:
			col = Color(0.86, 0.88, 0.74)
		elif mark == JournalLogic.Mark.RULED_OUT:
			col = Color(0.55, 0.50, 0.45)
		b.add_theme_color_override("font_color", col)
	for child in _notes_box.get_children():
		child.queue_free()
	if investigation.field_notes.is_empty():
		_notes_box.add_child(_note_label("Nothing recorded yet. Search the house with your equipment."))
	for note in investigation.field_notes:
		_notes_box.add_child(_note_label(note))
	var possible := investigation.possible_ghosts()
	for g in investigation.database.ghosts:
		var b: Button = _ghost_buttons[g.id]
		var ok := possible.has(g)
		var selected := investigation.selected_ghost_id == g.id
		b.text = "%s  %s%s" % ["●" if selected else "○", g.display_name, "" if ok else "   (excluded)"]
		b.disabled = not ok
		var ev_names: Array[String] = []
		for id in g.evidence:
			ev_names.append(investigation.database.get_evidence(id).display_name)
		(_ghost_details[g.id] as Label).text = "%s\nEvidence: %s" % [g.description, ", ".join(ev_names)]
		(_ghost_details[g.id] as Label).modulate.a = 1.0 if ok else 0.4
	var sel := investigation.selected_ghost()
	if possible.is_empty():
		_conclusion.text = "No known entity matches these notes. Re-check your evidence."
	elif sel:
		_conclusion.text = "Your conclusion: %s" % sel.display_name
	else:
		_conclusion.text = "Your conclusion: undecided"


func _note_label(text: String) -> Label:
	var l := UiTheme.make_label(text, 14, InkStyle.PAPER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(280, 0)
	return l


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	refresh()
	AudioManager.play(&"ui_page", -4.0)
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	AudioManager.play(&"ui_page", -6.0, 0.8)
	closed.emit()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func _process(_delta: float) -> void:
	if is_open and _time_label:
		_time_label.text = "time on site  %s" % investigation.time_string()
