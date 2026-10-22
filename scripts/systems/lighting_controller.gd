class_name LightingController
extends Node
## Global darkness (CanvasModulate), hunt flicker and night-vision tint.
## Presentation only: gameplay light queries go through [House].

var house: House
var modulate_node: CanvasModulate
var flickering: bool = false
var night_vision: bool = false
var _flicker_timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func setup(target_house: House, canvas_modulate: CanvasModulate) -> void:
	house = target_house
	modulate_node = canvas_modulate
	_rng.randomize()
	_apply_modulate()


func set_flicker(value: bool) -> void:
	flickering = value
	if not value:
		_reset_energy()


func set_night_vision(value: bool) -> void:
	night_vision = value
	_apply_modulate()


func _apply_modulate() -> void:
	if modulate_node:
		modulate_node.color = InkStyle.NIGHT_VISION if night_vision else InkStyle.DARKNESS


func _reset_energy() -> void:
	if house == null:
		return
	for room in house.room_list:
		for light in room.lights:
			light.energy = light.get_meta(&"base_energy", 1.0)


func _process(delta: float) -> void:
	if not flickering or house == null:
		return
	_flicker_timer -= delta
	if _flicker_timer > 0.0:
		return
	_flicker_timer = _rng.randf_range(0.04, 0.22)
	for room in house.room_list:
		for light in room.lights:
			var base: float = light.get_meta(&"base_energy", 1.0)
			light.energy = base * (_rng.randf_range(0.0, 0.25) if _rng.randf() < 0.55 else _rng.randf_range(0.6, 1.0))
