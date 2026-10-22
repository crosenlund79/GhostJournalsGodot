class_name AudioSynth
extends RefCounted
## Generates every placeholder sound procedurally at startup, so the project
## ships without any third-party audio. Replace a sound by dropping a file at
## res://assets/audio/<name>.ogg (or .wav); [AudioManager] prefers files.

const RATE: int = 22050


static func build_library() -> Dictionary:
	var lib := {}
	lib[&"footstep"] = _footstep()
	lib[&"door_open"] = _creak(0.55, 170.0, 250.0)
	lib[&"door_close"] = _thud(0.28, 75.0, 0.7)
	lib[&"door_slam"] = _thud(0.45, 55.0, 1.0)
	lib[&"door_locked"] = _rattle()
	lib[&"click"] = _click(0.035, 0.6)
	lib[&"emf_beep"] = _tone(0.07, 1450.0, 0.35)
	lib[&"static_loop"] = _static_loop()
	lib[&"whisper"] = _whisper(1.5)
	lib[&"ghost_voice"] = _ghost_voice(1.0)
	lib[&"manifest"] = _manifest()
	lib[&"hunt_start"] = _hunt_start()
	lib[&"heartbeat_loop"] = _heartbeat()
	lib[&"power_down"] = _sweep(1.0, 260.0, 35.0, 0.5)
	lib[&"power_up"] = _sweep(0.6, 50.0, 180.0, 0.35)
	lib[&"death"] = _death()
	lib[&"ui_click"] = _click(0.03, 0.25)
	lib[&"ui_page"] = _rustle()
	lib[&"ambience_loop"] = _ambience()
	lib[&"knock"] = _knock()
	lib[&"evidence_cue"] = _bell()
	lib[&"ritual_loop"] = _ritual_loop()
	lib[&"banish"] = _banish()
	lib[&"switch"] = _click(0.05, 0.45)
	return lib


static func to_stream(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream


static func _buffer(seconds: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * RATE))
	return buf


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


static func _footstep() -> AudioStreamWAV:
	var buf := _buffer(0.11)
	var r := _rng(11)
	var lp := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		lp += (r.randf_range(-1.0, 1.0) - lp) * 0.18
		buf[i] = (lp * 1.6 + sin(TAU * 90.0 * t) * 0.3) * exp(-t * 38.0)
	return to_stream(buf)


static func _creak(seconds: float, f0: float, f1: float) -> AudioStreamWAV:
	var buf := _buffer(seconds)
	var r := _rng(21)
	var phase := 0.0
	var lp := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		var k := t / seconds
		var f := lerpf(f0, f1, k) + sin(t * 37.0) * 12.0 + r.randf_range(-6.0, 6.0)
		phase = fmod(phase + f / RATE, 1.0)
		var saw := phase * 2.0 - 1.0
		lp += (saw - lp) * 0.12
		var grain := 0.6 + 0.4 * sin(TAU * 23.0 * t)
		buf[i] = lp * grain * sin(PI * k) * 0.55
	return to_stream(buf)


static func _thud(seconds: float, freq: float, strength: float) -> AudioStreamWAV:
	var buf := _buffer(seconds)
	var r := _rng(31)
	var lp := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		lp += (r.randf_range(-1.0, 1.0) - lp) * 0.25
		var body := sin(TAU * freq * t * (1.0 - t * 0.6)) * exp(-t * 11.0)
		var crack := lp * exp(-t * 60.0)
		buf[i] = (body * 0.8 + crack * 0.7) * strength
	return to_stream(buf)


static func _rattle() -> AudioStreamWAV:
	var buf := _buffer(0.45)
	var r := _rng(41)
	for i in buf.size():
		var t := float(i) / RATE
		var hit := fmod(t, 0.09)
		buf[i] = r.randf_range(-1.0, 1.0) * exp(-hit * 90.0) * 0.5 + sin(TAU * 420.0 * t) * exp(-hit * 70.0) * 0.25
	return to_stream(buf)


static func _click(seconds: float, strength: float) -> AudioStreamWAV:
	var buf := _buffer(seconds)
	var r := _rng(51)
	for i in buf.size():
		var t := float(i) / RATE
		buf[i] = (r.randf_range(-1.0, 1.0) * 0.5 + sin(TAU * 2200.0 * t) * 0.5) * exp(-t * 160.0) * strength
	return to_stream(buf)


static func _tone(seconds: float, freq: float, strength: float) -> AudioStreamWAV:
	var buf := _buffer(seconds)
	for i in buf.size():
		var t := float(i) / RATE
		var env := minf(1.0, t * 400.0) * minf(1.0, (seconds - t) * 300.0)
		buf[i] = sin(TAU * freq * t) * env * strength
	return to_stream(buf)


static func _static_loop() -> AudioStreamWAV:
	var buf := _buffer(1.0)
	var r := _rng(61)
	var lp := 0.0
	for i in buf.size():
		var n := r.randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.45
		var crackle := 0.0
		if r.randf() < 0.002:
			crackle = r.randf_range(-1.0, 1.0)
		buf[i] = (n - lp) * 0.28 + lp * 0.12 + crackle * 0.6
	return to_stream(buf, true)


static func _whisper(seconds: float) -> AudioStreamWAV:
	var buf := _buffer(seconds)
	var r := _rng(71)
	var lp1 := 0.0
	var lp2 := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		var n := r.randf_range(-1.0, 1.0)
		lp1 += (n - lp1) * 0.35
		lp2 += (n - lp2) * 0.05
		var band := lp1 - lp2
		var syllable := pow(maxf(0.0, sin(TAU * 4.3 * t + sin(t * 9.0))), 2.0)
		var env := sin(PI * t / seconds)
		buf[i] = band * syllable * env * 0.9
	return to_stream(buf)


static func _ghost_voice(seconds: float) -> AudioStreamWAV:
	var buf := _buffer(seconds)
	var r := _rng(81)
	var phase := 0.0
	var lp := 0.0
	var hp := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		var f := 105.0 + sin(TAU * 1.7 * t) * 18.0 + sin(TAU * 7.0 * t) * 6.0
		phase = fmod(phase + f / RATE, 1.0)
		var src := (phase * 2.0 - 1.0) * 0.6 + r.randf_range(-1.0, 1.0) * 0.35
		lp += (src - lp) * 0.2
		hp += (lp - hp) * 0.02
		var formant := (lp - hp)
		var env := pow(sin(PI * t / seconds), 0.6) * (0.55 + 0.45 * sin(TAU * 3.1 * t))
		buf[i] = formant * env * 1.2
	return to_stream(buf)


static func _manifest() -> AudioStreamWAV:
	var seconds := 2.2
	var buf := _buffer(seconds)
	var r := _rng(91)
	var lp := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		var k := t / seconds
		var drone := sin(TAU * 52.0 * t) * 0.5 + sin(TAU * 77.7 * t) * 0.3
		var rise := sin(TAU * (300.0 + 260.0 * k) * t) * 0.12 + sin(TAU * (317.0 + 250.0 * k) * t) * 0.12
		lp += (r.randf_range(-1.0, 1.0) - lp) * 0.08
		var env := sin(PI * k)
		buf[i] = (drone + rise + lp * 0.6) * env * 0.6
	return to_stream(buf)


static func _hunt_start() -> AudioStreamWAV:
	var seconds := 1.6
	var buf := _buffer(seconds)
	var r := _rng(101)
	var lp := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		var boom := sin(TAU * 38.0 * t * (1.0 - t * 0.2)) * exp(-t * 2.2)
		lp += (r.randf_range(-1.0, 1.0) - lp) * 0.06
		var screech := sin(TAU * 880.0 * t + sin(TAU * 13.0 * t) * 4.0) * exp(-t * 3.0) * 0.12
		buf[i] = (boom * 0.9 + lp * 0.7 * exp(-t * 1.5) + screech)
	return to_stream(buf)


static func _heartbeat() -> AudioStreamWAV:
	var seconds := 0.85
	var buf := _buffer(seconds)
	for i in buf.size():
		var t := float(i) / RATE
		var a := sin(TAU * 48.0 * t) * exp(-t * 22.0)
		var t2 := maxf(0.0, t - 0.22)
		var b := sin(TAU * 44.0 * t2) * exp(-t2 * 26.0) * 0.7 if t >= 0.22 else 0.0
		buf[i] = (a + b) * 0.9
	return to_stream(buf, true)


static func _sweep(seconds: float, f0: float, f1: float, strength: float) -> AudioStreamWAV:
	var buf := _buffer(seconds)
	var phase := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		var k := t / seconds
		var f := lerpf(f0, f1, k * k)
		phase = fmod(phase + f / RATE, 1.0)
		var hum := sin(TAU * phase) * 0.7 + sin(TAU * 60.0 * t) * 0.2
		buf[i] = hum * strength * (1.0 - k) * minf(1.0, t * 40.0)
	return to_stream(buf)


static func _death() -> AudioStreamWAV:
	var seconds := 1.6
	var buf := _buffer(seconds)
	var r := _rng(111)
	var phases := [0.0, 0.0, 0.0]
	var freqs := [620.0, 655.0, 930.0]
	for i in buf.size():
		var t := float(i) / RATE
		var k := t / seconds
		var s := 0.0
		for j in 3:
			var f: float = freqs[j] * (1.0 - k * 0.45)
			phases[j] = fmod(phases[j] + f / RATE, 1.0)
			s += (phases[j] * 2.0 - 1.0) * 0.22
		s += r.randf_range(-1.0, 1.0) * 0.35
		s += sin(TAU * 41.0 * t) * 0.6 * exp(-t * 2.0)
		buf[i] = s * minf(1.0, t * 60.0) * (1.0 - k)
	return to_stream(buf)


static func _rustle() -> AudioStreamWAV:
	var buf := _buffer(0.25)
	var r := _rng(121)
	var lp := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		var n := r.randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.5
		buf[i] = (n - lp) * 0.35 * sin(PI * t / 0.25) * (0.5 + 0.5 * absf(sin(TAU * 31.0 * t)))
	return to_stream(buf)


static func _ambience() -> AudioStreamWAV:
	var seconds := 6.0
	var buf := _buffer(seconds)
	var r := _rng(131)
	var lp := 0.0
	var lp2 := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		lp += (r.randf_range(-1.0, 1.0) - lp) * 0.02
		lp2 += (lp - lp2) * 0.05
		# Modulation frequencies complete whole cycles inside the loop.
		var gust := 0.55 + 0.45 * sin(TAU * t / seconds) * sin(TAU * 2.0 * t / seconds)
		var drone := sin(TAU * 46.0 * t) * 0.07 + sin(TAU * 69.0 * t) * 0.04
		buf[i] = lp2 * 3.2 * gust + drone
	return to_stream(buf, true)


static func _knock() -> AudioStreamWAV:
	var buf := _buffer(0.5)
	for i in buf.size():
		var t := float(i) / RATE
		var t2 := maxf(0.0, t - 0.22)
		var k1 := sin(TAU * 140.0 * t) * exp(-t * 45.0)
		var k2 := sin(TAU * 130.0 * t2) * exp(-t2 * 45.0) if t >= 0.22 else 0.0
		buf[i] = (k1 + k2) * 0.8
	return to_stream(buf)


static func _bell() -> AudioStreamWAV:
	var seconds := 1.6
	var buf := _buffer(seconds)
	for i in buf.size():
		var t := float(i) / RATE
		var s := sin(TAU * 196.0 * t) * 0.5 + sin(TAU * 293.7 * t) * 0.3 + sin(TAU * 523.0 * t) * 0.1
		buf[i] = s * exp(-t * 2.4) * minf(1.0, t * 80.0) * 0.45
	return to_stream(buf)


static func _ritual_loop() -> AudioStreamWAV:
	var seconds := 2.0
	var buf := _buffer(seconds)
	for i in buf.size():
		var t := float(i) / RATE
		var pulse := 0.6 + 0.4 * sin(TAU * t / seconds * 2.0)
		buf[i] = (sin(TAU * 110.0 * t) * 0.3 + sin(TAU * 165.0 * t) * 0.18 + sin(TAU * 220.5 * t) * 0.08) * pulse
	return to_stream(buf, true)


static func _banish() -> AudioStreamWAV:
	var seconds := 2.4
	var buf := _buffer(seconds)
	var r := _rng(141)
	var lp := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		var k := t / seconds
		lp += (r.randf_range(-1.0, 1.0) - lp) * (0.3 - k * 0.25)
		var tone := sin(TAU * (440.0 - 300.0 * k) * t) * 0.25
		buf[i] = (lp * 0.8 + tone) * (1.0 - k) * minf(1.0, t * 20.0)
	return to_stream(buf)
