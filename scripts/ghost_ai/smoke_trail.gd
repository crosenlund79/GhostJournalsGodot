class_name SmokeTrail
extends Node2D
## Ink-wash smoke left behind a visible, moving ghost. Each puff drifts,
## swells and fades. Puffs obey the same perception rule as the ghost: the
## investigator only sees smoke they are looking at. All puffs are drawn by
## this one node for efficiency.

## World distance the ghost travels between puffs.
const SPACING := 5.0
const LIFETIME := 2.0
const MAX_PUFFS := 120

var enabled: bool = true
var player: Player
var _puffs: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	material = InkStyle.unshaded_material()
	_rng.randomize()


func puff_count() -> int:
	return _puffs.size()


func emit_puff(world_position: Vector2, drift: Vector2, strength: float) -> void:
	if not enabled:
		return
	if _puffs.size() >= MAX_PUFFS:
		_puffs.pop_front()
	_puffs.append({
		"pos": world_position + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-3, 3)),
		"vel": drift * _rng.randf_range(6.0, 14.0) + Vector2(_rng.randf_range(-5, 5), _rng.randf_range(-7, -2)),
		"age": 0.0,
		"strength": clampf(strength, 0.0, 1.0),
		"size": _rng.randf_range(6.0, 10.0),
		"spin": _rng.randf_range(0.0, TAU),
		"seen": 0.0,
	})


func _process(delta: float) -> void:
	if _puffs.is_empty():
		return
	var i := _puffs.size() - 1
	while i >= 0:
		var p := _puffs[i]
		p["age"] += delta
		if p["age"] >= LIFETIME:
			_puffs.remove_at(i)
		else:
			p["pos"] += p["vel"] * delta
			p["vel"] *= 1.0 - minf(1.0, delta * 1.8)
			var target: float = player.perceive(p["pos"]) if player and not player.is_dead else 1.0
			p["seen"] = move_toward(p["seen"], minf(1.0, target * 1.6), delta * 6.0)
		i -= 1
	queue_redraw()


func _draw() -> void:
	for p in _puffs:
		var k: float = p["age"] / LIFETIME
		var a: float = p["strength"] * p["seen"] * pow(1.0 - k, 1.4)
		if a <= 0.01:
			continue
		var r: float = p["size"] * (1.0 + k * 1.6)
		var c: Vector2 = p["pos"]
		# Grey wash body, pale core and a broken ink wisp, matching the token's cloth.
		draw_circle(c, r, Color(0.40, 0.40, 0.42, a * 0.38))
		draw_circle(c + Vector2(-r * 0.2, -r * 0.25), r * 0.6, Color(0.72, 0.72, 0.74, a * 0.22))
		var start: float = p["spin"] + k * 2.0
		draw_arc(c, r * 0.9, start, start + 2.2, 8, Color(InkStyle.INK, a * 0.5), InkStyle.DETAIL_WIDTH, true)
