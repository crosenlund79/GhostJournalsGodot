class_name DebugOverlay
extends CanvasLayer
## Debug readout (only exists when debug mode is enabled from the main menu
## or with the --debug-mode user argument).

var investigation_root: Node
var _label: Label
var _panel: PanelContainer


func _ready() -> void:
	layer = 50
	_panel = PanelContainer.new()
	UiTheme.place(_panel, Vector2(1, 0), Rect2(-370, 14, 356, 330))
	_panel.theme = UiTheme.get_theme()
	var style := UiTheme.panel_style(Color(0, 0, 0, 0.7), Color(0.6, 0.2, 0.2))
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_label = Label.new()
	_label.add_theme_font_override("font", ThemeDB.fallback_font)
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.7))
	_panel.add_child(_label)
	visible = false


func set_text(text: String) -> void:
	_label.text = text
