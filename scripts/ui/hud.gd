class_name Hud
extends CanvasLayer
## Minimal in-investigation HUD: held equipment and its reading, the
## interaction prompt, a subtle composure (sanity) indicator, the current
## room and quiet notifications. Reads state; never drives gameplay.

var player: Player
var investigation: InvestigationManager
var safe_room: SafeRoomController
var hunt_director: HuntDirector

var _root: Control
var _vignette: TextureRect
var _room_label: Label
var _room_fade: float = 0.0
var _composure_bar: ProgressBar
var _composure_label: Label
var _stamina_bar: ProgressBar
var _notice_label: Label
var _notice_time: float = 0.0
var _prompt_label: Label
var _hold_bar: ProgressBar
var _hold_status: Label
var _slot_panels: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []
var _item_label: Label
var _reading_label: Label
var _ward_label: Label
var _monologue: Label
var _monologue_time: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	_build_vignette()
	_build_top()
	_build_prompt()
	_build_slots()
	_build_monologue()


func setup(target_player: Player, manager: InvestigationManager, safe: SafeRoomController, director: HuntDirector) -> void:
	player = target_player
	investigation = manager
	safe_room = safe
	hunt_director = director
	investigation.notification.connect(show_notice)
	player.room_changed.connect(_on_room_changed)
	player.equipment.inventory_changed.connect(_refresh_slots)
	player.equipment.selected_changed.connect(func(_i: int) -> void: _refresh_slots())
	_refresh_slots()


func _build_vignette() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 1))
	g.add_point(0.55, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 0.5)
	tex.width = 256
	tex.height = 256
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_vignette)


func _build_top() -> void:
	var box := VBoxContainer.new()
	UiTheme.place(box, Vector2(0, 0), Rect2(22, 18, 260, 110))
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	_room_label = UiTheme.make_label("", 20, InkStyle.PAPER)
	_room_label.modulate.a = 0.0
	box.add_child(_room_label)
	_composure_label = UiTheme.make_label("composure", 12, InkStyle.PAPER_MUTED)
	box.add_child(_composure_label)
	_composure_bar = ProgressBar.new()
	_composure_bar.custom_minimum_size = Vector2(130, 5)
	_composure_bar.show_percentage = false
	_composure_bar.max_value = 100.0
	box.add_child(_composure_bar)
	_stamina_bar = ProgressBar.new()
	_stamina_bar.custom_minimum_size = Vector2(130, 3)
	_stamina_bar.show_percentage = false
	_stamina_bar.max_value = 1.0
	_stamina_bar.modulate = Color(1, 1, 1, 0.5)
	box.add_child(_stamina_bar)
	_ward_label = UiTheme.make_label("", 14, InkStyle.LIGHT_WARD)
	box.add_child(_ward_label)

	_notice_label = UiTheme.make_label("", 18, InkStyle.PAPER)
	UiTheme.place(_notice_label, Vector2(0.5, 0), Rect2(-400, 26, 800, 60))
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_notice_label)

	var hint := UiTheme.make_label("J  journal     Esc  pause", 12, Color(InkStyle.PAPER_MUTED, 0.6))
	UiTheme.place(hint, Vector2(1, 1), Rect2(-220, -32, 200, 20))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(hint)


func _build_prompt() -> void:
	var box := VBoxContainer.new()
	UiTheme.place(box, Vector2(0.5, 1), Rect2(-300, -170, 600, 100))
	box.alignment = BoxContainer.ALIGNMENT_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	_prompt_label = UiTheme.make_label("", 18, InkStyle.PAPER)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_prompt_label)
	_hold_bar = ProgressBar.new()
	_hold_bar.custom_minimum_size = Vector2(220, 4)
	_hold_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hold_bar.show_percentage = false
	_hold_bar.max_value = 1.0
	_hold_bar.visible = false
	box.add_child(_hold_bar)
	_hold_status = UiTheme.make_label("", 14, InkStyle.PAPER_MUTED)
	_hold_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_hold_status)


func _build_slots() -> void:
	var box := VBoxContainer.new()
	UiTheme.place(box, Vector2(0, 1), Rect2(22, -112, 320, 96))
	box.alignment = BoxContainer.ALIGNMENT_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	_item_label = UiTheme.make_label("", 17, InkStyle.PAPER)
	box.add_child(_item_label)
	_reading_label = UiTheme.make_label("", 15, InkStyle.PAPER_MUTED)
	box.add_child(_reading_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for i in EquipmentManager.SLOT_COUNT:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(64, 30)
		var label := UiTheme.make_label("", 12, InkStyle.PAPER_MUTED)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(label)
		row.add_child(panel)
		_slot_panels.append(panel)
		_slot_labels.append(label)


func _build_monologue() -> void:
	_monologue = UiTheme.make_label("", 19, Color(0.86, 0.82, 0.74))
	var italic := UiTheme.serif_font()
	(italic as SystemFont).font_italic = true
	_monologue.add_theme_font_override("font", italic)
	_monologue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_monologue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.place(_monologue, Vector2(0.5, 1), Rect2(-380, -250, 760, 70))
	_monologue.modulate.a = 0.0
	_root.add_child(_monologue)


## The investigator's thoughts, shown as a quiet italic line.
func show_monologue(text: String) -> void:
	_monologue.text = "“%s”" % text
	_monologue_time = 6.0


func monologue_text() -> String:
	return _monologue.text if _monologue_time > 0.0 else ""


func _refresh_slots() -> void:
	if player == null:
		return
	for i in EquipmentManager.SLOT_COUNT:
		var item := player.equipment.slots[i]
		var selected := i == player.equipment.selected_index
		_slot_labels[i].text = "%d  %s" % [i + 1, item.definition.short_name if item else "—"]
		_slot_labels[i].add_theme_color_override("font_color", InkStyle.PAPER if selected else InkStyle.PAPER_MUTED)
		var style := UiTheme.panel_style(Color(0.16, 0.14, 0.12, 0.92) if selected else Color(0.08, 0.07, 0.06, 0.75),
			Color(0.70, 0.62, 0.50) if selected else Color(0.30, 0.27, 0.22))
		style.set_content_margin_all(4)
		style.shadow_size = 0
		_slot_panels[i].add_theme_stylebox_override("panel", style)


func show_notice(text: String, tone: StringName = &"info") -> void:
	_notice_label.text = text
	_notice_time = 4.5
	var col := InkStyle.PAPER
	match tone:
		&"danger":
			col = Color(0.85, 0.55, 0.48)
		&"evidence":
			col = Color(0.82, 0.86, 0.72)
	_notice_label.add_theme_color_override("font_color", col)


func _on_room_changed(room: RoomData) -> void:
	_room_label.text = room.display_name
	_room_fade = 3.0
	if room.is_safe_room and safe_room:
		show_notice("The warding lamp burns. You feel watched over." if safe_room.protected
			else "The warding lamp is dark. Nothing protects this room.", &"info")


func _process(delta: float) -> void:
	_time += delta
	if player == null:
		return
	# Room name fades in and out.
	_room_fade = maxf(0.0, _room_fade - delta)
	_room_label.modulate.a = clampf(_room_fade, 0.0, 1.0)
	_notice_time = maxf(0.0, _notice_time - delta)
	_notice_label.modulate.a = clampf(_notice_time, 0.0, 1.0)
	_monologue_time = maxf(0.0, _monologue_time - delta)
	_monologue.modulate.a = clampf(minf(_monologue_time, 6.0 - _monologue_time) * 1.5, 0.0, 1.0)
	# Composure.
	var s := player.sanity.value
	_composure_bar.value = s
	_composure_bar.modulate = Color(1, 1, 1, 0.45 + (1.0 - s / 100.0) * 0.5)
	_stamina_bar.value = player.stamina
	_stamina_bar.visible = player.stamina < 0.99
	# Vignette tightens with low sanity and during hunts.
	var intensity := 0.35 + (1.0 - s / 100.0) * 0.45
	if hunt_director and hunt_director.is_hunting:
		intensity = 0.85 + sin(_time * 7.0) * 0.1
	_vignette.modulate = Color(0.25, 0.02, 0.02, intensity) if hunt_director and hunt_director.is_hunting else Color(1, 1, 1, intensity)
	# Ward status while in the safe room.
	var in_safe := safe_room and player.house and player.house.get_room_at(player.global_position) == safe_room.room
	_ward_label.text = ("warded" if safe_room.protected else "unprotected") if in_safe else ""
	# Equipment.
	var item := player.equipment.get_current()
	if item:
		_item_label.text = item.display_name()
		var hint := item.definition.use_hint
		_reading_label.text = "%s     F  %s" % [item.get_hud_reading(), hint]
	else:
		_item_label.text = "Empty hands"
		_reading_label.text = "G  drop     1-4  select"
	# Prompt.
	var prompt := player.interaction.get_prompt_text() if player.can_act() else ""
	_prompt_label.text = prompt
	_hold_bar.visible = player.interaction.holding
	_hold_bar.value = player.interaction.hold_progress
	_hold_status.text = player.interaction.get_hold_status()
