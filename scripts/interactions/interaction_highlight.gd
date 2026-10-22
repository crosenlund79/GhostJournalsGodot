class_name InteractionHighlight
extends Node2D
## Subtle ink corner brackets around the focused interactable. Unshaded so it
## stays readable in darkness without looking like bright game UI.

var extent: Vector2 = Vector2(14, 14)
var _time: float = 0.0


func _ready() -> void:
	material = InkStyle.unshaded_material()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var e := extent + Vector2.ONE * (3.0 + sin(_time * 3.0) * 1.0)
	var col := Color(InkStyle.PAPER, 0.55)
	var l := minf(7.0, minf(e.x, e.y))
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := Vector2(e.x * sx, e.y * sy)
			draw_line(corner, corner - Vector2(l * sx, 0), col, InkStyle.DETAIL_WIDTH * 1.4)
			draw_line(corner, corner - Vector2(0, l * sy), col, InkStyle.DETAIL_WIDTH * 1.4)
