class_name TV
extends Appliance
## Old CRT television. Switched on it shows only static: a crawling noise
## picture, a hiss, and flickering light in classic TV hues filling the room.

const HUES: Array[Color] = [
	Color(0.55, 0.65, 1.0), Color(0.45, 0.85, 0.95), Color(0.85, 0.88, 1.0),
	Color(0.70, 0.55, 0.95), Color(0.60, 0.95, 0.80),
]

var _light: PointLight2D
var _hiss: AudioStreamPlayer2D
var _screen: Node2D
var _hue_timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	appliance_name = "TV"
	needs_power = true
	highlight_extent = Vector2(14, 10)
	_rng.randomize()
	rotation = facing.angle() - PI * 0.5  # local +Y faces the room
	_light = PointLight2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	_light.texture = tex
	_light.texture_scale = 5.0 * InkStyle.TILE * 2.0 / 128.0
	_light.position = Vector2(0, 14)
	_light.shadow_enabled = true
	_light.enabled = false
	add_child(_light)
	_hiss = AudioStreamPlayer2D.new()
	_hiss.stream = AudioManager.get_stream(&"static_loop")
	_hiss.bus = &"Ambience"
	_hiss.volume_db = -4.0
	_hiss.max_distance = 520.0
	add_child(_hiss)
	_screen = Node2D.new()
	_screen.material = InkStyle.unshaded_material()
	_screen.draw.connect(_draw_screen)
	add_child(_screen)
	super._ready()


func _apply_state() -> void:
	if _light == null:
		return
	_light.enabled = is_on
	if is_on:
		_hiss.play()
	else:
		_hiss.stop()
	_screen.queue_redraw()


func is_playing_static() -> bool:
	return is_on and _hiss.playing


func _process(delta: float) -> void:
	if not is_on:
		return
	_hue_timer -= delta
	if _hue_timer <= 0.0:
		_hue_timer = _rng.randf_range(0.05, 0.25)
		_light.color = HUES[_rng.randi() % HUES.size()]
	_light.energy = _rng.randf_range(0.55, 1.05)
	_screen.queue_redraw()


func _draw() -> void:
	# CRT seen from above: deep cabinet, screen at the front (+Y).
	InkStyle.draw_box(self, Rect2(Vector2(-13, -9), Vector2(26, 16)), InkStyle.fill(&"wood").darkened(0.35), 7101)
	InkStyle.draw_box(self, Rect2(Vector2(-8, -12), Vector2(16, 4)), InkStyle.fill(&"metal").darkened(0.4), 7102, InkStyle.DETAIL_WIDTH)
	draw_line(Vector2(-4, -12), Vector2(-9, -18), InkStyle.INK, InkStyle.DETAIL_WIDTH)
	draw_line(Vector2(4, -12), Vector2(9, -18), InkStyle.INK, InkStyle.DETAIL_WIDTH)


func _draw_screen() -> void:
	var r := Rect2(Vector2(-11, 3), Vector2(22, 5))
	if not is_on:
		_screen.draw_rect(r, Color(0.12, 0.13, 0.14))
		_screen.draw_rect(r, InkStyle.INK, false, InkStyle.DETAIL_WIDTH)
		return
	# Static: random grey speckles on a pale glowing screen.
	_screen.draw_rect(r, Color(0.75, 0.80, 0.90))
	for i in 40:
		var p := r.position + Vector2(_rng.randf() * r.size.x, _rng.randf() * r.size.y)
		var v := _rng.randf()
		_screen.draw_rect(Rect2(p, Vector2(1.2, 1.2)), Color(v, v, v * 1.05))
	_screen.draw_rect(r, InkStyle.INK, false, InkStyle.DETAIL_WIDTH)
	# Spill of light on the floor in front of the screen.
	_screen.draw_rect(Rect2(Vector2(-12, 8), Vector2(24, 3)), Color(_light.color, 0.25))
