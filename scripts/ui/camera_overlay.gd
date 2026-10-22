class_name CameraOverlay
extends CanvasLayer
## Viewfinder shown while the video camera records: tint, scanlines, frame
## brackets and a blinking REC mark.

var _canvas: Control
var _time: float = 0.0


func _ready() -> void:
	layer = 5
	visible = false
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_overlay)
	add_child(_canvas)


func set_recording(on: bool) -> void:
	visible = on


func _process(delta: float) -> void:
	if visible:
		_time += delta
		_canvas.queue_redraw()


func _draw_overlay() -> void:
	var size := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.6, 0.4, 0.07))
	var y := fmod(_time * 40.0, 4.0)
	while y < size.y:
		_canvas.draw_line(Vector2(0, y), Vector2(size.x, y), Color(0, 0, 0, 0.10), 1.0)
		y += 4.0
	var m := 40.0
	var l := 46.0
	var col := Color(0.85, 0.95, 0.85, 0.65)
	for corner in [Vector2(m, m), Vector2(size.x - m, m), Vector2(m, size.y - m), Vector2(size.x - m, size.y - m)]:
		var sx := 1.0 if corner.x < size.x * 0.5 else -1.0
		var sy := 1.0 if corner.y < size.y * 0.5 else -1.0
		_canvas.draw_line(corner, corner + Vector2(l * sx, 0), col, 2.0)
		_canvas.draw_line(corner, corner + Vector2(0, l * sy), col, 2.0)
	var font := ThemeDB.fallback_font
	if fmod(_time, 1.0) < 0.6:
		_canvas.draw_circle(Vector2(size.x - m - 150, m + 26), 6.0, Color(0.85, 0.2, 0.15, 0.9))
	_canvas.draw_string(font, Vector2(size.x - m - 138, m + 32), "REC", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
	_canvas.draw_string(font, Vector2(size.x - m - 150, m + 54), "NIGHTSHOT  %05.1f" % fmod(_time, 999.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
