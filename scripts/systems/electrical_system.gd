class_name ElectricalSystem
extends Node
## House-wide electrical power. Circuits are named so further circuits can be
## added later; the prototype uses a single "main" circuit.

signal power_changed(is_on: bool, reason: String)

const MAIN := &"main"

var _circuits: Dictionary = {MAIN: false}


func is_powered(circuit: StringName = MAIN) -> bool:
	return _circuits.get(circuit, false)


func set_power(on: bool, reason: String = "player", circuit: StringName = MAIN) -> void:
	if _circuits.get(circuit, false) == on:
		return
	_circuits[circuit] = on
	AudioManager.play(&"power_up" if on else &"power_down", -4.0)
	power_changed.emit(on, reason)


func toggle(reason: String = "player") -> void:
	set_power(not is_powered(), reason)


## Called by ghost logic to disrupt the power.
func trip(reason: String = "ghost") -> void:
	set_power(false, reason)
