class_name PlayerVisual
extends Node2D
## Top-down investigator placeholder: shoulders, head and a facing nose-mark.
## Rotated by [Player] to its facing. Replace with
## res://assets/sprites/player/investigator.png (drawn facing +X).

var walk_phase: float = 0.0
var _texture: Texture2D


func _ready() -> void:
	_texture = InkStyle.try_texture("player/investigator")


func _draw() -> void:
	if _texture:
		draw_texture(_texture, -_texture.get_size() * 0.5)
		return
	var sway := sin(walk_phase) * 1.6
	# Feet peek out ahead/behind while walking.
	InkStyle.draw_oval(self, Vector2(3.0 + sway, -4.5), Vector2(3.5, 2.2), InkStyle.INK.lightened(0.15), 501, InkStyle.DETAIL_WIDTH)
	InkStyle.draw_oval(self, Vector2(3.0 - sway, 4.5), Vector2(3.5, 2.2), InkStyle.INK.lightened(0.15), 502, InkStyle.DETAIL_WIDTH)
	# Shoulders / coat.
	InkStyle.draw_oval(self, Vector2(-1, 0), Vector2(6.5, 10.5), Color(0.30, 0.31, 0.27), 503)
	InkStyle.draw_detail(self, Vector2(-6, 0), Vector2(3, 0), 504, InkStyle.INK_FADED)
	# Head with hair.
	InkStyle.draw_oval(self, Vector2(0.5, 0), Vector2(4.6, 4.6), Color(0.62, 0.52, 0.42), 505)
	InkStyle.draw_oval(self, Vector2(-1.2, 0), Vector2(3.4, 4.2), Color(0.20, 0.16, 0.12), 506, InkStyle.DETAIL_WIDTH)
	# Facing mark.
	draw_line(Vector2(4.5, 0), Vector2(7.0, 0), InkStyle.INK, InkStyle.DETAIL_WIDTH)
