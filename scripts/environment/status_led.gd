class_name StatusLed
extends Node2D
## Tiny unshaded indicator light, readable in darkness.

var color: Color = InkStyle.BLOOD
var radius: float = 2.0


func _ready() -> void:
	material = InkStyle.unshaded_material()
	z_index = 1


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 1.5, Color(color, 0.18))
	draw_circle(Vector2.ZERO, radius, color)
