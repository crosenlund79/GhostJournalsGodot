class_name Appliance
extends Interactable
## Something that can be switched on and off by the player, the ghost or the
## doll (TVs, radios). Subclasses implement [method _apply_state].

signal toggled(appliance: Appliance, is_on: bool, by: StringName)

var house: House
var room: RoomData
var is_on: bool = false
## Mains-powered appliances die with the house power.
var needs_power: bool = true
## Direction the front of the appliance faces (away from its wall).
var facing: Vector2 = Vector2.DOWN
var appliance_name: String = "Appliance"


func _ready() -> void:
	interaction_range = 48.0
	super._ready()
	add_to_group(&"appliance")
	z_index = -3
	if house and house.electrical and needs_power:
		house.electrical.power_changed.connect(func(on: bool, _r: String) -> void:
			if not on and is_on:
				set_on(false, &"power"))
	_apply_state()


func get_prompt(_actor: Node) -> String:
	return "Turn %s %s" % [appliance_name, "Off" if is_on else "On"]


func interact(actor: Node) -> void:
	set_on(not is_on, &"player")
	super.interact(actor)


## Returns false if it could not change (e.g. no power).
func set_on(on: bool, by: StringName = &"player") -> bool:
	if on == is_on:
		return true
	if on and needs_power and house and not house.is_power_on():
		AudioManager.play_at(&"switch", global_position, -4.0, 0.8)
		return false
	is_on = on
	AudioManager.play_at(&"switch", global_position, -2.0)
	_apply_state()
	queue_redraw()
	toggled.emit(self, is_on, by)
	return true


func toggle(by: StringName) -> bool:
	return set_on(not is_on, by)


func _apply_state() -> void:
	pass
