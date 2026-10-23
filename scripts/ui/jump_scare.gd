class_name JumpScare
extends CanvasLayer
## Full-screen jump scare played when the ghost catches the investigator.
##
## Phases: RUSH (the splash image flies from the ghost's on-screen position
## toward the investigator, accelerating and growing until it covers the
## screen) -> HOLD (a brief violent shudder) -> FOG (the image bursts into a
## cloud of fog that hides the screen) -> CLEAR (the fog thins and is gone).

signal covered
signal finished

const RUSH_TIME := 0.32
const HOLD_TIME := 0.16
const FOG_TIME := 0.6
const CLEAR_TIME := 0.9
const TOTAL_TIME := RUSH_TIME + HOLD_TIME + FOG_TIME + CLEAR_TIME
## Size of the splash at the start (roughly the ghost token on screen).
const START_SIZE := 90.0
const FOG_PUFFS := 46

var texture: Texture2D
var playing: bool = false
var elapsed: float = 0.0

var _canvas: Control
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _covered_sent: bool = false
var _fog: Array[Dictionary] = []
var _fog_texture: Texture2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 42  # above HUD and journal; the death screen (40) fades in beneath the fog
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_rng.randomize()
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_canvas.draw.connect(_draw_scare)
	add_child(_canvas)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.7))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	_fog_texture = tex


## Starts the scare. Positions are in screen (viewport) coordinates.
func play(splash: Texture2D, from_screen: Vector2, to_screen: Vector2) -> void:
	texture = splash
	_from = from_screen
	_to = to_screen
	elapsed = 0.0
	playing = true
	_covered_sent = false
	_fog.clear()
	visible = true


func is_covering() -> bool:
	return playing and elapsed >= RUSH_TIME and elapsed < RUSH_TIME + HOLD_TIME + FOG_TIME


func _process(delta: float) -> void:
	if not playing:
		return
	elapsed += delta
	if not _covered_sent and elapsed >= RUSH_TIME:
		_covered_sent = true
		_spawn_fog()
		covered.emit()
	for f in _fog:
		f["pos"] += f["vel"] * delta
	if elapsed >= TOTAL_TIME:
		playing = false
		visible = false
		_fog.clear()
		finished.emit()
		return
	_canvas.queue_redraw()


func _spawn_fog() -> void:
	var size := _canvas.size
	for i in FOG_PUFFS:
		# Burst outward from where the face filled the screen.
		var angle := _rng.randf() * TAU
		var dist := _rng.randf_range(0.0, size.length() * 0.45)
		var pos := _to + Vector2(cos(angle), sin(angle)) * dist
		_fog.append({
			"pos": pos,
			"vel": Vector2(cos(angle), sin(angle)) * _rng.randf_range(60.0, 220.0),
			"radius": _rng.randf_range(140.0, 340.0),
			"shade": _rng.randf_range(0.62, 0.86),
		})


func _draw_scare() -> void:
	var size := _canvas.size
	var cover := maxf(size.x, size.y) * 1.35
	if elapsed < RUSH_TIME + HOLD_TIME + FOG_TIME * 0.6 and texture:
		var center: Vector2
		var side: float
		var alpha := 1.0
		if elapsed < RUSH_TIME:
			# Accelerating lunge: slow start, then fills the screen in a blink.
			var k := pow(elapsed / RUSH_TIME, 2.6)
			center = _from.lerp(_to, minf(1.0, k * 1.15))
			side = lerpf(START_SIZE, cover, k)
		else:
			center = _to
			side = cover
			var hold_k := (elapsed - RUSH_TIME) / HOLD_TIME
			if hold_k < 1.0:
				center += Vector2(_rng.randf_range(-14, 14), _rng.randf_range(-10, 10))
				side *= 1.0 + hold_k * 0.04
			else:
				var fog_k := (elapsed - RUSH_TIME - HOLD_TIME) / (FOG_TIME * 0.6)
				alpha = 1.0 - fog_k
				side *= 1.04 + fog_k * 0.25
		var rect := Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side))
		# A dark flash behind the face sells the impact.
		if elapsed >= RUSH_TIME * 0.6:
			_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55 * alpha))
		_canvas.draw_texture_rect(texture, rect, false, Color(1, 1, 1, alpha))
	if _fog.is_empty():
		return
	# Fog density: rises quickly as the face dissolves, then thins away.
	var t := elapsed - RUSH_TIME - HOLD_TIME
	var density := 0.0
	if t < 0.0:
		density = 0.0
	elif t < FOG_TIME:
		density = smoothstep(0.0, FOG_TIME * 0.5, t)
	else:
		density = 1.0 - smoothstep(0.0, CLEAR_TIME, t - FOG_TIME)
	if density <= 0.0:
		return
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.70, 0.70, 0.72, density * 0.45))
	# Overlapping puffs saturate, so they thin faster than the veil to really clear.
	var puff_alpha := pow(density, 2.2) * 0.8
	for f in _fog:
		var r: float = f["radius"] * (1.0 + maxf(t, 0.0) * 0.5)
		var shade: float = f["shade"]
		var c: Vector2 = f["pos"]
		_canvas.draw_texture_rect(_fog_texture, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false,
			Color(shade, shade, shade + 0.02, puff_alpha))
