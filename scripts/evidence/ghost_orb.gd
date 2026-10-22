class_name GhostOrb
extends Node2D
## Faint orb drifting through the ghost's favourite room. Only visible through
## an active video camera (see [VideoCamera]).

signal recorded(orb: GhostOrb)

var house: House
var room: RoomData
var seen_amount: float = 0.0
var recorded_once: bool = false
var _target: Vector2
var _visible_this_frame: bool = false
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"ghost_orb")
	material = InkStyle.unshaded_material()
	z_index = 25
	_rng.randomize()
	_pick_target()


func _pick_target() -> void:
	if room == null or house == null:
		_target = position
		return
	var cell := room.cells[_rng.randi() % room.cells.size()]
	_target = house.cell_to_world(cell) + Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-10, 10))


## Called by the active camera when this orb is in frame.
func mark_seen() -> void:
	_visible_this_frame = true


func _process(delta: float) -> void:
	_time += delta
	global_position = global_position.move_toward(_target, delta * 14.0)
	if global_position.distance_to(_target) < 2.0:
		_pick_target()
	var target_alpha := 1.0 if _visible_this_frame else 0.0
	_visible_this_frame = false
	seen_amount = move_toward(seen_amount, target_alpha, delta * 4.0)
	if seen_amount >= 0.6 and not recorded_once:
		recorded_once = true
		recorded.emit(self)
	queue_redraw()


func _draw() -> void:
	var a := seen_amount * (0.65 + sin(_time * 5.0) * 0.25)
	if a <= 0.01 and not (GameManager.debug_enabled and DebugFlags.show_world_debug):
		return
	if a <= 0.01:
		draw_arc(Vector2.ZERO, 4.0, 0.0, TAU, 10, Color(0.6, 1, 0.6, 0.4), 1.0)
		return
	draw_circle(Vector2.ZERO, 7.0, Color(InkStyle.ORB, a * 0.2))
	draw_circle(Vector2.ZERO, 3.2, Color(InkStyle.ORB, a))
