class_name UvPrint
extends Node2D
## Fluorescent handprint left by a ghost. Invisible unless a UV flashlight's
## beam is on it (see [UvFlashlight]).

signal revealed(print_node: UvPrint)

const FADE_SPEED := 2.5

var reveal: float = 0.0
var was_revealed: bool = false
var room_name: String = ""
var _lit_this_frame: bool = false
var _seed: int = 0


func _ready() -> void:
	add_to_group(&"uv_print")
	material = InkStyle.unshaded_material()
	z_index = 20
	_seed = randi()
	rotation = randf_range(-0.6, 0.6)


## Called by an active UV flashlight while the print is inside its beam.
func illuminate() -> void:
	_lit_this_frame = true


func _process(delta: float) -> void:
	var target := 1.0 if _lit_this_frame else 0.0
	_lit_this_frame = false
	var before := reveal
	reveal = move_toward(reveal, target, delta * FADE_SPEED)
	if reveal >= 0.5 and not was_revealed:
		was_revealed = true
		revealed.emit(self)
	if not is_equal_approx(before, reveal):
		queue_redraw()


func _draw() -> void:
	if reveal <= 0.01:
		return
	var col := Color(InkStyle.UV_PRINT, 0.85 * reveal)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	# Palm.
	draw_colored_polygon(InkStyle.jitter_points(InkStyle.ellipse_points(Vector2(0, 2), Vector2(4.2, 5.0), 12), _seed, 0.5), col)
	# Fingers.
	for i in 4:
		var x := -3.6 + i * 2.4
		var length := 4.5 + rng.randf_range(0.0, 1.8) + (1.0 if i == 1 or i == 2 else 0.0)
		draw_line(Vector2(x, -2), Vector2(x * 1.1, -2 - length), col, 1.8)
	draw_line(Vector2(4, 2), Vector2(7.5, -1.5), col, 1.8)
