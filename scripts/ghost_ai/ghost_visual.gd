class_name GhostVisual
extends Node2D
## Presentation of the ghost. Normally an indistinct dark silhouette; when it
## catches the player it briefly becomes a pale, detailed horror. Unshaded:
## visibility is decided by perception logic, not by lamps.
## Replacements: res://assets/sprites/ghost/silhouette.png and horror.png.

var horror: bool = false
var _time: float = 0.0
var _horror_scale: float = 1.0
var _banish_t: float = -1.0
var _tex_silhouette: Texture2D
var _tex_horror: Texture2D


func _ready() -> void:
	material = InkStyle.unshaded_material()
	_tex_silhouette = InkStyle.try_texture("ghost/silhouette")
	_tex_horror = InkStyle.try_texture("ghost/horror")


func set_horror(value: bool) -> void:
	horror = value
	_horror_scale = 1.0


func play_banish() -> void:
	_banish_t = 0.0


func _process(delta: float) -> void:
	_time += delta
	if horror:
		_horror_scale = move_toward(_horror_scale, 2.1, delta * 3.0)
	if _banish_t >= 0.0:
		_banish_t += delta
		modulate.a = maxf(0.0, 1.0 - _banish_t / 2.0)
		if _banish_t > 2.0:
			_banish_t = -1.0
	if modulate.a > 0.01:
		queue_redraw()


func _draw() -> void:
	if modulate.a <= 0.01:
		return
	if horror:
		_draw_horror()
	else:
		_draw_silhouette()


func _draw_silhouette() -> void:
	if _tex_silhouette:
		draw_texture(_tex_silhouette, -_tex_silhouette.get_size() * 0.5)
		return
	var body := InkStyle.GHOST_BODY
	# A faint pale haze so the dark figure separates from dark floors.
	draw_circle(Vector2(-2, 0), 24.0, Color(0.55, 0.57, 0.62, 0.07))
	draw_circle(Vector2(-1, 0), 17.0, Color(0.55, 0.57, 0.62, 0.10))
	# Trailing wisps behind the figure (local -X is behind).
	for i in 4:
		var y := -7.0 + i * 4.6
		var wave := sin(_time * 3.0 + i * 1.7) * 3.0
		var pts := PackedVector2Array([Vector2(-4, y * 0.8), Vector2(-12, y + wave * 0.5), Vector2(-20 - i, y * 1.2 + wave)])
		draw_polyline(pts, Color(body, 0.55), 3.0 - i * 0.4, true)
	# Shoulders: a slightly irregular dark mass.
	var shoulders := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		var r := Vector2(7.5, 13.0) * (1.0 + sin(a * 3.0 + _time * 2.3) * 0.07)
		shoulders.append(Vector2(cos(a) * r.x - 1.5, sin(a) * r.y))
	draw_colored_polygon(shoulders, body)
	var rim := shoulders.duplicate()
	rim.append(shoulders[0])
	draw_polyline(rim, Color(InkStyle.GHOST_RIM, 0.45), InkStyle.DETAIL_WIDTH, true)
	# Long arms reaching forward.
	for s in [-1.0, 1.0]:
		var reach := 12.0 + sin(_time * 1.7 + s) * 2.0
		draw_line(Vector2(2, s * 9.0), Vector2(reach, s * 7.5), body, 3.0, true)
	# Head.
	draw_circle(Vector2(1.5, 0), 6.0, body)
	draw_arc(Vector2(1.5, 0), 6.0, 0.0, TAU, 18, Color(InkStyle.GHOST_RIM, 0.4), InkStyle.DETAIL_WIDTH, true)


func _draw_horror() -> void:
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE * _horror_scale)
	if _tex_horror:
		draw_texture(_tex_horror, -_tex_horror.get_size() * 0.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_time * 12.0)
	# Hair strands lashing outward.
	for i in 22:
		var a := TAU * float(i) / 22.0 + rng.randf_range(-0.08, 0.08)
		var inner := Vector2(cos(a), sin(a)) * 8.0
		var outer := Vector2(cos(a), sin(a)) * rng.randf_range(15.0, 22.0)
		draw_line(inner, outer, InkStyle.GHOST_BODY, 1.6, true)
	# Pale face.
	var face := InkStyle.jitter_points(InkStyle.ellipse_points(Vector2.ZERO, Vector2(8.5, 10.5), 20), int(_time * 20.0), 0.6)
	draw_colored_polygon(face, InkStyle.GHOST_FACE)
	var outline := face.duplicate()
	outline.append(face[0])
	draw_polyline(outline, InkStyle.INK, InkStyle.OUTLINE_WIDTH * 0.6, true)
	# Hollow eyes with pinprick pupils.
	for s in [-1.0, 1.0]:
		var eye := Vector2(3.4 * s, -2.5)
		draw_colored_polygon(InkStyle.ellipse_points(eye, Vector2(2.3, 2.9), 12), InkStyle.INK)
		draw_circle(eye + Vector2(0, 0.4), 0.6, InkStyle.BLOOD.lightened(0.4))
		draw_line(eye + Vector2(0, 2.9), eye + Vector2(0.3 * s, 6.5), Color(InkStyle.INK, 0.7), 0.8)
	# Stretched mouth.
	var mouth := PackedVector2Array([Vector2(-3.2, 4.0), Vector2(0, 3.4), Vector2(3.2, 4.0), Vector2(1.8, 8.6), Vector2(-1.8, 8.6)])
	draw_colored_polygon(mouth, InkStyle.INK)
	for i in 4:
		var x := -2.2 + i * 1.5
		draw_line(Vector2(x, 4.0), Vector2(x, 5.2), InkStyle.GHOST_FACE, 0.6)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
