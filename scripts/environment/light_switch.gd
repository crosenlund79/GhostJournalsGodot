class_name LightSwitch
extends Interactable
## Wall switch for a room's ceiling light. Only matters while power is on.

signal toggled_by(actor: Node, on: bool)

var room: RoomData
var house: House


func _ready() -> void:
	highlight_extent = Vector2(6, 8)
	interaction_range = 40.0
	super._ready()
	z_index = 2


func get_prompt(_actor: Node) -> String:
	if room == null:
		return ""
	return "Switch Light Off" if room.light_switch_on else "Switch Light On"


func interact(actor: Node) -> void:
	set_on(not room.light_switch_on)
	super.interact(actor)
	toggled_by.emit(actor, room.light_switch_on)


func set_on(on: bool, silent: bool = false) -> void:
	if room == null or house == null:
		return
	house.set_room_light(room, on)
	if not silent:
		AudioManager.play_at(&"switch", global_position, -6.0)
	queue_redraw()


func _draw() -> void:
	var plate := Rect2(Vector2(-4, -6), Vector2(8, 12))
	InkStyle.draw_box(self, plate, InkStyle.PAPER_MUTED, 77, InkStyle.DETAIL_WIDTH * 1.3)
	var on := room != null and room.light_switch_on
	var toggle := Rect2(Vector2(-1.5, -4.0 if on else 0.0), Vector2(3, 4))
	draw_rect(toggle, InkStyle.INK)
