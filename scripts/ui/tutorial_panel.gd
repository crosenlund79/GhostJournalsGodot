class_name TutorialPanel
extends CanvasLayer
## Instruction card for the Learn to Play mode.

var _panel: PanelContainer
var _progress: Label
var _title: Label
var _body: Label
var _footer: Label
var _status: Label
var _flash: float = 0.0


func _ready() -> void:
	layer = 11
	_panel = PanelContainer.new()
	UiTheme.place(_panel, Vector2(1, 0), Rect2(-420, 16, 400, 10))
	_panel.theme = UiTheme.get_theme()
	var style := UiTheme.panel_style(Color(0.10, 0.09, 0.075, 0.9), Color(0.55, 0.49, 0.38))
	style.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	_progress = UiTheme.make_label("", 12, InkStyle.PAPER_MUTED)
	box.add_child(_progress)
	_title = UiTheme.make_label("", 20, InkStyle.PAPER, true)
	box.add_child(_title)
	_body = UiTheme.make_label("", 15, InkStyle.PAPER)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(372, 0)
	box.add_child(_body)
	_status = UiTheme.make_label("", 14, InkStyle.LIGHT_WARD)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(372, 0)
	_status.visible = false
	box.add_child(_status)
	_footer = UiTheme.make_label("Tab — skip this step", 12, InkStyle.PAPER_MUTED)
	box.add_child(_footer)


func show_step(index: int, total: int, title: String, text: String) -> void:
	_progress.text = "LEARN TO PLAY  ·  step %d of %d" % [index + 1, total]
	_title.text = title
	_body.text = text
	_footer.visible = true
	_flash = 1.0
	# Shrink to fit the new text.
	_panel.reset_size()


## Live hint reacting to the current situation ("" hides it).
func set_status(text: String) -> void:
	if _status.text == text:
		return
	_status.text = text
	_status.visible = text != ""
	_panel.reset_size()


func show_done() -> void:
	set_status("")
	_progress.text = "LEARN TO PLAY  ·  complete"
	_title.text = "Training complete"
	_body.text = "You know the tools. Hold E at the van door when you are ready to leave, or keep practising."
	_footer.visible = false
	_flash = 1.0
	_panel.reset_size()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 1.5)
		_panel.modulate = Color(1, 1, 1, 1).lerp(Color(1.35, 1.3, 1.1, 1), _flash)
