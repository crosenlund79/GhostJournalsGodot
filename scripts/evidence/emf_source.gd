class_name EmfSource
extends Node2D
## Invisible electromagnetic disturbance left by ghost activity. Read by the
## EMF reader; level 5 only ever comes from ghosts with "EMF Level 5" evidence.

var level: int = 2
var lifetime: float = 20.0
var _age: float = 0.0


static func spawn(parent: Node, world_position: Vector2, emf_level: int, duration: float = 20.0) -> EmfSource:
	var src := EmfSource.new()
	src.level = emf_level
	src.lifetime = duration
	parent.add_child(src)
	src.global_position = world_position
	return src


func _ready() -> void:
	add_to_group(&"emf_source")
	material = InkStyle.unshaded_material()
	z_index = 40


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
	elif GameManager.debug_enabled:
		queue_redraw()


func _draw() -> void:
	if GameManager.debug_enabled and DebugFlags.show_world_debug:
		draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 16, Color(1, 0.4, 0.2, 0.7), 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-4, 4), str(level), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.5, 0.3))
