class_name SafeRoomController
extends Node
## Owns the safe room's protection. The warding lamp is wired to house power:
## protected while power is on, vulnerable when it is off.

signal protection_changed(protected: bool)

var house: House
var electrical: ElectricalSystem
var room: RoomData
var lamp: WardingLamp
var protected: bool = false


func setup(target_house: House, electrical_system: ElectricalSystem, ward_lamp: WardingLamp) -> void:
	house = target_house
	electrical = electrical_system
	room = house.safe_room
	lamp = ward_lamp
	electrical.power_changed.connect(func(_on: bool, _r: String) -> void: _evaluate())
	_evaluate(true)


func _evaluate(initial: bool = false) -> void:
	var now := room != null and electrical.is_powered()
	if now == protected and not initial:
		return
	protected = now
	house.set_room_blocked(room, protected)
	if lamp:
		lamp.set_lit(protected)
	protection_changed.emit(protected)


func is_position_protected(world_position: Vector2) -> bool:
	return protected and house.get_room_at(world_position) == room
