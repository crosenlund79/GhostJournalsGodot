class_name TutorialMarker
extends Node2D
## Pulsing ink ring that points at the current tutorial objective. Unshaded so
## it reads in the dark; hidden when the objective has no location.

## World position (Vector2) or null.
var target: Variant = null
## When set, a chevron beside this node points toward a distant objective.
var player: Node2D
var _time: float = 0.0


func _ready() -> void:
	material = InkStyle.unshaded_material()
	z_index = 60


func _process(delta: float) -> void:
	_time += delta
	visible = target is Vector2
	if visible:
		global_position = target
		queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 3.5)
	var col := Color(InkStyle.LIGHT_WARD, 0.35 + pulse * 0.35)
	draw_arc(Vector2.ZERO, 14.0 + pulse * 4.0, 0.0, TAU, 32, col, 1.6, true)
	var bob := -26.0 - pulse * 4.0
	draw_colored_polygon(PackedVector2Array([Vector2(-6, bob), Vector2(6, bob), Vector2(0, bob + 8)]), col)
	# Objective far away: a chevron orbiting the investigator points at it.
	if player and is_instance_valid(player):
		var to_target := global_position - player.global_position
		if to_target.length() > 150.0:
			var dir := to_target.normalized()
			var c := to_local(player.global_position + dir * (30.0 + pulse * 3.0))
			var side := dir.orthogonal()
			draw_colored_polygon(PackedVector2Array([c + dir * 7.0, c - dir * 3.0 + side * 6.0, c - dir * 3.0 - side * 6.0]), col)
