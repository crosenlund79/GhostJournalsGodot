extends Node
## Autoload: audio categories (buses), sound library and playback helpers.
##
## Sounds are referenced by name. A file at res://assets/audio/<name>.ogg or
## .wav overrides the procedurally generated placeholder of the same name.

const BUSES: Array[StringName] = [&"Ambience", &"Equipment", &"Ghost", &"Player", &"UI", &"Music", &"Radio"]
## The old radio's song (looped while a radio is on).
const RADIO_MUSIC_PATH := "res://audio/Where Did Everybody Go - alternate.mp3"

## Default category for each sound name.
const CATEGORY := {
	&"footstep": &"Player",
	&"door_open": &"Ambience", &"door_close": &"Ambience", &"door_slam": &"Ghost", &"door_locked": &"Ambience",
	&"click": &"Equipment", &"emf_beep": &"Equipment", &"static_loop": &"Equipment", &"switch": &"Equipment",
	&"whisper": &"Ghost", &"ghost_voice": &"Ghost", &"manifest": &"Ghost", &"hunt_start": &"Ghost",
	&"heartbeat_loop": &"Music", &"knock": &"Ghost", &"banish": &"Ghost",
	&"power_down": &"Ambience", &"power_up": &"Ambience",
	&"death": &"Ghost", &"ui_click": &"UI", &"ui_page": &"UI", &"evidence_cue": &"UI",
	&"ambience_loop": &"Ambience", &"ritual_loop": &"Music",
	&"hunt_drone": &"Music", &"growl": &"Ghost", &"giggle": &"Ghost",
}

var _streams: Dictionary = {}
var _loops: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_streams = AudioSynth.build_library()
	for sound_name in _streams.keys():
		for ext in ["ogg", "wav"]:
			var path := "res://assets/audio/%s.%s" % [sound_name, ext]
			if ResourceLoader.exists(path):
				_streams[sound_name] = load(path)
				break


func _setup_buses() -> void:
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, &"Master")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Ambience"), -6.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Music"), -4.0)
	# Old-radio colour: band-limited, slightly overdriven.
	var radio := AudioServer.get_bus_index(&"Radio")
	if AudioServer.get_bus_effect_count(radio) == 0:
		var band := AudioEffectBandPassFilter.new()
		band.cutoff_hz = 1400.0
		band.resonance = 0.6
		AudioServer.add_bus_effect(radio, band)
		var dist := AudioEffectDistortion.new()
		dist.mode = AudioEffectDistortion.MODE_OVERDRIVE
		dist.drive = 0.35
		dist.pre_gain = 4.0
		dist.post_gain = -3.0
		AudioServer.add_bus_effect(radio, dist)
	# Hunt mix: the house's ambience is muffled while something hunts.
	var amb := AudioServer.get_bus_index(&"Ambience")
	if AudioServer.get_bus_effect_count(amb) == 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 600.0
		AudioServer.add_bus_effect(amb, lp)
		AudioServer.set_bus_effect_enabled(amb, 0, false)


## Muffles ambience (and ducks it) during hunts.
func set_hunt_mix(on: bool) -> void:
	var amb := AudioServer.get_bus_index(&"Ambience")
	AudioServer.set_bus_effect_enabled(amb, 0, on)
	AudioServer.set_bus_volume_db(amb, -11.0 if on else -6.0)


## The radio song as a looping stream (null if the file is missing).
func radio_music() -> AudioStream:
	if not _streams.has(&"radio_music"):
		var stream: AudioStream = load(RADIO_MUSIC_PATH) if ResourceLoader.exists(RADIO_MUSIC_PATH) else null
		if stream is AudioStreamMP3:
			stream = (stream as AudioStreamMP3).duplicate()
			(stream as AudioStreamMP3).loop = true
		_streams[&"radio_music"] = stream
	return _streams[&"radio_music"]


func get_stream(sound_name: StringName) -> AudioStream:
	return _streams.get(sound_name)


func has_sound(sound_name: StringName) -> bool:
	return _streams.has(sound_name)


## Non-positional one-shot (UI, the player's own equipment, stingers).
func play(sound_name: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	var stream := get_stream(sound_name)
	if stream == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = CATEGORY.get(sound_name, &"Master")
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


## Plays an arbitrary stream once (e.g. a ghost's own catch scream).
func play_stream(stream: AudioStream, volume_db: float = 0.0, bus: StringName = &"Ghost", pitch: float = 1.0) -> AudioStreamPlayer:
	if stream == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = bus
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


## Positional one-shot in the current scene (ghost activity, doors...).
func play_at(sound_name: StringName, world_position: Vector2, volume_db: float = 0.0,
		pitch: float = 1.0, max_distance: float = 720.0) -> AudioStreamPlayer2D:
	var stream := get_stream(sound_name)
	var scene := get_tree().current_scene
	if stream == null or scene == null:
		return null
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.max_distance = max_distance
	p.attenuation = 1.6
	p.bus = CATEGORY.get(sound_name, &"Master")
	p.global_position = world_position
	scene.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


## Starts (or keeps) a named looping sound. Loops survive until stopped.
func start_loop(key: StringName, sound_name: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if _loops.has(key) and is_instance_valid(_loops[key]):
		var existing: AudioStreamPlayer = _loops[key]
		existing.volume_db = volume_db
		existing.pitch_scale = pitch
		return
	var stream := get_stream(sound_name)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = CATEGORY.get(sound_name, &"Master")
	add_child(p)
	p.play()
	_loops[key] = p


func set_loop_volume(key: StringName, volume_db: float) -> void:
	if _loops.has(key) and is_instance_valid(_loops[key]):
		(_loops[key] as AudioStreamPlayer).volume_db = volume_db


func set_loop_pitch(key: StringName, pitch: float) -> void:
	if _loops.has(key) and is_instance_valid(_loops[key]):
		(_loops[key] as AudioStreamPlayer).pitch_scale = pitch


func stop_loop(key: StringName) -> void:
	if _loops.has(key):
		var p: AudioStreamPlayer = _loops[key]
		if is_instance_valid(p):
			p.stop()
			p.stream = null
			p.queue_free()
		_loops.erase(key)


func _exit_tree() -> void:
	stop_all_loops()
	_streams.clear()


func stop_all_loops() -> void:
	for key in _loops.keys():
		stop_loop(key)
