class_name Door
extends Interactable
## Hinged door occupying one wall cell. Blocks movement and light when closed.
## Usable by the player (E) and by ghost logic ([method ghost_toggle]).

signal door_toggled(door: Door, is_open: bool, by_ghost: bool)

enum DoorAxis { HORIZONTAL, VERTICAL }

const TILE := InkStyle.TILE
const THICKNESS := 7.0

## HORIZONTAL = the door sits in a horizontal wall (spans along x).
@export var orientation: DoorAxis = DoorAxis.HORIZONTAL
@export var is_front_door: bool = false
@export var start_open: bool = false

var cell: Vector2i
var is_open: bool = false
var locked: bool = false
## Doors touched by the ghost may carry UV handprints.
var uv_prints: Array[Node2D] = []

var _body: StaticBody2D
var _shape: CollisionShape2D
var _occluder: LightOccluder2D
var _swing: float = 0.0
var _texture_closed: Texture2D


func _ready() -> void:
	highlight_extent = Vector2(TILE * 0.5, THICKNESS) if orientation == DoorAxis.HORIZONTAL else Vector2(THICKNESS, TILE * 0.5)
	interaction_range = 44.0
	super._ready()
	add_to_group(&"doors")
	_texture_closed = InkStyle.try_texture("environment/door")
	_body = StaticBody2D.new()
	_body.collision_layer = House.WALL_LAYER
	_body.collision_mask = 0
	_shape = CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(TILE, THICKNESS) if orientation == DoorAxis.HORIZONTAL else Vector2(THICKNESS, TILE)
	_shape.shape = rs
	_body.add_child(_shape)
	add_child(_body)
	_occluder = LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	var half := rs.size * 0.5
	poly.polygon = InkStyle.rect_points(Rect2(-half, rs.size))
	_occluder.occluder = poly
	add_child(_occluder)
	is_open = not start_open
	set_open(start_open, false, true)


func get_prompt(_actor: Node) -> String:
	if locked:
		return "Locked"
	return "Close Door" if is_open else "Open Door"


func interact(actor: Node) -> void:
	if locked:
		AudioManager.play_at(&"door_locked", global_position)
		return
	set_open(not is_open)
	super.interact(actor)


func set_open(open: bool, by_ghost: bool = false, silent: bool = false) -> void:
	if open == is_open:
		return
	is_open = open
	_shape.set_deferred("disabled", open)
	_occluder.visible = not open
	if not silent:
		if open:
			AudioManager.play_at(&"door_open", global_position, -2.0, randf_range(0.9, 1.1))
		else:
			AudioManager.play_at(&"door_slam" if by_ghost else &"door_close", global_position, 0.0 if by_ghost else -3.0)
	door_toggled.emit(self, open, by_ghost)


## Ghost interaction: toggles the door. Locked doors only rattle.
func ghost_toggle() -> void:
	if locked:
		AudioManager.play_at(&"door_locked", global_position, 2.0)
		return
	set_open(not is_open, true)


func set_locked(value: bool) -> void:
	locked = value
	if locked and is_open:
		set_open(false, true)


func _process(delta: float) -> void:
	var target := 1.0 if is_open else 0.0
	if not is_equal_approx(_swing, target):
		_swing = move_toward(_swing, target, delta * 4.0)
		queue_redraw()


func _draw() -> void:
	var along := Vector2.RIGHT if orientation == DoorAxis.HORIZONTAL else Vector2.DOWN
	var across := Vector2.DOWN if orientation == DoorAxis.HORIZONTAL else Vector2.RIGHT
	var half := TILE * 0.5
	# Frame jambs.
	for s in [-1.0, 1.0]:
		var p: Vector2 = along * half * s
		draw_line(p - across * 5.0, p + across * 5.0, InkStyle.INK, InkStyle.OUTLINE_WIDTH)
	# Panel rotates around a hinge at one end of the opening.
	var hinge := -along * (half - 1.0)
	var swing_dir := 1.0 if not is_front_door else -1.0
	var angle := _swing * PI * 0.5 * swing_dir
	var dir := along.rotated(angle)
	var normal := across.rotated(angle)
	var length := TILE - 2.0
	if _texture_closed and _swing < 0.01:
		draw_set_transform(Vector2.ZERO, along.angle(), Vector2.ONE)
		draw_texture_rect(_texture_closed, Rect2(Vector2(-half, -THICKNESS * 0.5), Vector2(TILE, THICKNESS)), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var t := THICKNESS * 0.42
	var pts := PackedVector2Array([
		hinge - normal * t,
		hinge + dir * length - normal * t,
		hinge + dir * length + normal * t,
		hinge + normal * t,
	])
	var fill := InkStyle.fill(&"wood").darkened(0.15) if not is_front_door else InkStyle.RUST.darkened(0.35)
	InkStyle.draw_shape(self, pts, fill, cell.x * 31 + cell.y, InkStyle.INK, InkStyle.OUTLINE_WIDTH * 0.85)
	# Handle.
	draw_circle(hinge + dir * (length - 5.0) + normal * (t + 1.5), 1.6, InkStyle.INK)
	if locked:
		draw_circle(hinge + dir * (length * 0.5), 2.2, InkStyle.BLOOD)
