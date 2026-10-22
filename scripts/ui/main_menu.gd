extends Control
## Title screen.

var _debug_toggle: Button
var _time: float = 0.0
var _ghost_option: OptionButton
var _art: Control


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = InkStyle.PAPER_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var art := Control.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(_draw_backdrop.bind(art))
	add_child(art)
	_art = art

	var box := VBoxContainer.new()
	UiTheme.place(box, Vector2(0.5, 0.5), Rect2(-300, -250, 600, 500))
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var title := UiTheme.make_label("GHOST JOURNALS", 54, InkStyle.PAPER, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UiTheme.make_label("Case 01 — The Hollow Lane House", 18, InkStyle.PAPER_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(HSeparator.new())
	var start := UiTheme.make_button("Begin Investigation", _on_start)
	box.add_child(start)
	_debug_toggle = Button.new()
	_debug_toggle.toggle_mode = true
	_debug_toggle.button_pressed = GameManager.debug_enabled
	_debug_toggle.toggled.connect(func(on: bool) -> void:
		AudioManager.play(&"ui_click", -6.0)
		GameManager.debug_enabled = on
		_ghost_option.visible = on
		_refresh_debug_text())
	box.add_child(_debug_toggle)
	_ghost_option = OptionButton.new()
	_ghost_option.add_item("Ghost: random")
	for g in GameManager.database.ghosts:
		_ghost_option.add_item("Ghost: %s" % g.display_name)
	_ghost_option.visible = GameManager.debug_enabled
	_ghost_option.item_selected.connect(func(i: int) -> void:
		GameManager.forced_ghost_id = &"" if i == 0 else GameManager.database.ghosts[i - 1].id)
	box.add_child(_ghost_option)
	box.add_child(UiTheme.make_button("Quit", func() -> void: GameManager.quit_game()))
	var controls := UiTheme.make_label(
		"WASD move   Mouse aim   Shift sprint\nE interact (hold for some)   F use equipment   G drop\n1–4 select equipment   J journal   Esc pause",
		14, InkStyle.PAPER_MUTED)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(controls)
	var brief := UiTheme.make_label(
		"Find the fuse box. Gather evidence. Name what haunts the house.\nThen leave — if it lets you.",
		15, Color(InkStyle.PAPER, 0.8))
	brief.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(brief)
	_refresh_debug_text()
	start.grab_focus()
	AudioManager.start_loop(&"menu_ambience", &"ambience_loop", -8.0)


func _exit_tree() -> void:
	AudioManager.stop_loop(&"menu_ambience")


func _refresh_debug_text() -> void:
	_debug_toggle.text = "Debug mode: %s" % ("ON  (F3 overlay, F4–F10 tools)" if GameManager.debug_enabled else "off")


func _on_start() -> void:
	GameManager.start_investigation()


func _process(delta: float) -> void:
	_time += delta
	_art.queue_redraw()


## A faint ink drawing of a house outline behind the menu.
func _draw_backdrop(c: Control) -> void:
	var size := c.size
	var base := Vector2(size.x * 0.5, size.y * 0.5 + 40)
	var col := Color(InkStyle.PAPER, 0.06)
	var w := 520.0
	var h := 300.0
	var roof := PackedVector2Array([base + Vector2(-w * 0.5, -h * 0.5), base + Vector2(0, -h * 0.95), base + Vector2(w * 0.5, -h * 0.5)])
	c.draw_polyline(InkStyle.jitter_points(roof, 5, 2.0), col, 3.0, true)
	var body := InkStyle.jitter_points(InkStyle.rect_points(Rect2(base - Vector2(w * 0.5, h * 0.5), Vector2(w, h))), 6, 2.0)
	body.append(body[0])
	c.draw_polyline(body, col, 3.0, true)
	for i in 3:
		var win := Rect2(base + Vector2(-w * 0.38 + i * w * 0.3, -h * 0.3), Vector2(60, 70))
		var flicker := 0.05 + 0.04 * maxf(0.0, sin(_time * (1.3 + i) + i * 2.0))
		c.draw_rect(win, Color(1.0, 0.8, 0.5, flicker if i == 1 else 0.02))
		var pts := InkStyle.jitter_points(InkStyle.rect_points(win), 10 + i, 1.5)
		pts.append(pts[0])
		c.draw_polyline(pts, col, 2.0, true)
