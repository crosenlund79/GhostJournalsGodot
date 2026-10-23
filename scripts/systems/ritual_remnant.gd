class_name RitualRemnant
extends Node2D
## What is left after a ritual circle is picked up: a scorched, warped
## pentagram and scattered salt, so you can see a rite was prepared here.

var _seed: int = 0


func _ready() -> void:
	add_to_group(&"ritual_remnant")
	z_index = -13
	_seed = randi() % 100000


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	# Soot stain.
	draw_colored_polygon(InkStyle.jitter_points(InkStyle.ellipse_points(Vector2.ZERO, Vector2(25, 22), 22), _seed, 4.0), Color(0.05, 0.04, 0.04, 0.35))
	# Broken, smeared outer ring.
	var ring := InkStyle.jitter_points(InkStyle.ellipse_points(Vector2(1, -1), Vector2(22, 21), 30), _seed + 1, 2.6)
	for i in ring.size():
		if rng.randf() < 0.3:
			continue  # gaps where the salt was scuffed away
		draw_line(ring[i], ring[(i + 1) % ring.size()], Color(InkStyle.PAPER, 0.35), 2.0, true)
	# Warped star: points pulled off true and some strokes missing.
	var pts: Array[Vector2] = []
	for i in 5:
		var a := TAU * float(i) / 5.0 - PI * 0.5 + rng.randf_range(-0.18, 0.18)
		pts.append(Vector2(cos(a), sin(a)) * rng.randf_range(12.0, 18.0))
	for i in 5:
		if rng.randf() < 0.2:
			continue
		var a := pts[i]
		var b := pts[(i + 2) % 5]
		var mid := (a + b) * 0.5 + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
		draw_polyline(PackedVector2Array([a, mid, b]), Color(InkStyle.BLOOD.darkened(0.3), 0.6), 1.2, true)
	# Wax drips where candles stood, scattered salt grains.
	for p in pts:
		draw_circle(p * 1.15 + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2)), rng.randf_range(1.4, 2.4), Color(InkStyle.PAPER_MUTED, 0.5))
	for i in 26:
		var a := rng.randf() * TAU
		var r := rng.randf_range(16.0, 30.0)
		draw_circle(Vector2(cos(a), sin(a)) * r, 0.7, Color(InkStyle.PAPER, 0.4))
