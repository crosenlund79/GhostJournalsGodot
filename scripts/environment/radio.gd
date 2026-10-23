class_name Radio
extends Appliance
## Battery radio. Switched on it plays the old song on repeat through a
## distorted band-limited bus, its volume drifting, with bursts of static
## breaking in now and then. Runs until someone (player, ghost or doll)
## turns it off.

const QUIET_DB := -16.0
const LOUD_DB := -3.0

var _music: AudioStreamPlayer2D
var _static: AudioStreamPlayer2D
var _volume_target: float = -8.0
var _volume_timer: float = 0.0
var _static_timer: float = 0.0
var _static_left: float = 0.0
var _wobble: float = 0.0
var _led: StatusLed
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	appliance_name = "Radio"
	needs_power = false
	highlight_extent = Vector2(10, 8)
	_rng.randomize()
	rotation = facing.angle() - PI * 0.5
	_music = AudioStreamPlayer2D.new()
	_music.stream = AudioManager.radio_music()
	_music.bus = &"Radio"
	_music.max_distance = 900.0
	_music.attenuation = 1.3
	add_child(_music)
	_static = AudioStreamPlayer2D.new()
	_static.stream = AudioManager.get_stream(&"static_loop")
	_static.bus = &"Equipment"
	_static.max_distance = 700.0
	add_child(_static)
	_led = StatusLed.new()
	_led.radius = 1.4
	_led.color = Color(1.0, 0.75, 0.4)
	_led.position = Vector2(5, 3)
	add_child(_led)
	super._ready()


func _apply_state() -> void:
	if _music == null:
		return
	_led.visible = is_on
	if is_on:
		_music.volume_db = _rng.randf_range(-10.0, -6.0)
		_music.play(_rng.randf_range(0.0, 20.0))
		_volume_timer = 0.0
		_static_timer = _rng.randf_range(3.0, 8.0)
	else:
		_music.stop()
		_static.stop()


func is_playing_music() -> bool:
	return is_on and _music.playing


func _process(delta: float) -> void:
	if not is_on:
		return
	# Drifting volume: sometimes barely there, sometimes too loud.
	_volume_timer -= delta
	if _volume_timer <= 0.0:
		_volume_timer = _rng.randf_range(3.0, 9.0)
		_volume_target = _rng.randf_range(QUIET_DB, LOUD_DB)
	_music.volume_db = move_toward(_music.volume_db, _volume_target, delta * 4.0)
	# Warble: a slow, uneven pitch drift like a tired tape.
	_wobble += delta
	_music.pitch_scale = 0.985 + sin(_wobble * 0.7) * 0.012 + sin(_wobble * 2.3) * 0.004
	# Static breaking in on top of the song.
	if _static_left > 0.0:
		_static_left -= delta
		if _static_left <= 0.0:
			_static.stop()
	else:
		_static_timer -= delta
		if _static_timer <= 0.0:
			_static_timer = _rng.randf_range(5.0, 14.0)
			_static_left = _rng.randf_range(0.3, 1.6)
			_static.volume_db = _rng.randf_range(-12.0, -2.0)
			_static.play(_rng.randf_range(0.0, 0.8))
	queue_redraw()


func _draw() -> void:
	InkStyle.draw_box(self, Rect2(Vector2(-9, -5), Vector2(18, 11)), InkStyle.RUST.darkened(0.35), 7201, InkStyle.OUTLINE_WIDTH * 0.8)
	draw_circle(Vector2(-3, 1), 3.2, InkStyle.PAPER_DARK)
	draw_arc(Vector2(-3, 1), 3.2, 0.0, TAU, 12, InkStyle.INK, InkStyle.DETAIL_WIDTH)
	draw_line(Vector2(6, -5), Vector2(12, -13), InkStyle.INK, InkStyle.DETAIL_WIDTH)
	if is_on:
		# Ink sound-waves pulsing from the speaker.
		var pulse := fmod(_wobble * 1.4, 1.0)
		for i in 2:
			var k := fmod(pulse + i * 0.5, 1.0)
			draw_arc(Vector2(0, 6), 6.0 + k * 10.0, 0.4, PI - 0.4, 10, Color(InkStyle.PAPER, 0.5 * (1.0 - k)), InkStyle.DETAIL_WIDTH)
