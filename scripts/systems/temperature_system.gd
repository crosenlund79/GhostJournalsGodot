class_name TemperatureSystem
extends Node
## Simulates room temperatures. The ghost's favourite room grows cold; ghosts
## with "Freezing Temperatures" evidence push it below zero.

const UPDATE_INTERVAL := 0.5
const APPROACH_RATE := 0.28  # degrees per second
const OUTDOOR_TEMPERATURE := 9.0

var house: House
var ghost: GhostController
var electrical: ElectricalSystem
var _timer: float = 0.0


func setup(target_house: House, ghost_controller: GhostController, electrical_system: ElectricalSystem) -> void:
	house = target_house
	ghost = ghost_controller
	electrical = electrical_system
	# Give the favourite room a head start so the cold is findable early.
	if ghost and ghost.favorite_room:
		ghost.favorite_room.temperature = ghost.favorite_room.base_temperature - 6.0


func _process(delta: float) -> void:
	if house == null:
		return
	_timer += delta
	if _timer < UPDATE_INTERVAL:
		return
	var step := _timer
	_timer = 0.0
	for room in house.indoor_rooms():
		var target := target_temperature(room)
		room.temperature = move_toward(room.temperature, target, APPROACH_RATE * step)


func target_temperature(room: RoomData) -> float:
	var target := room.base_temperature
	if electrical and not electrical.is_powered():
		target -= 1.5
	if ghost == null or not ghost.is_active():
		return target
	var freezing := ghost.definition.has_evidence(&"freezing")
	if room == ghost.favorite_room:
		target = -4.5 if freezing else 6.5
	if room == ghost.current_room:
		target -= 2.0
		if not freezing:
			target = maxf(target, 3.0)
	return target


func get_temperature_at(world_position: Vector2) -> float:
	var room := house.get_room_at(world_position)
	if room == null or room.is_outdoors:
		return OUTDOOR_TEMPERATURE
	return room.temperature
