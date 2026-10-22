class_name Equipment
extends Node2D
## Base class for handheld equipment. Lives under the player's equipment
## anchor, which rotates with facing; local +X is "forward". Subclasses
## override the virtual hooks and never depend on animation frames.

signal state_changed(item: Equipment)

var definition: EquipmentDefinition
var player: Player
var active: bool = false
var held: bool = false
var _texture: Texture2D


func _ready() -> void:
	if definition:
		_texture = InkStyle.try_texture("equipment/%s" % definition.id)


## F key. Default behaviour is toggling on/off.
func use() -> void:
	set_active(not active)


func set_active(value: bool) -> void:
	if value == active:
		return
	if value and not held:
		return
	active = value
	AudioManager.play(&"click", -6.0)
	if active:
		_on_activated()
	else:
		_on_deactivated()
	state_changed.emit(self)
	queue_redraw()


func set_held(value: bool) -> void:
	held = value
	visible = value
	if not held and active:
		set_active(false)


func display_name() -> String:
	return definition.display_name if definition else name


## Short status for the HUD ("ON", a reading...).
func get_hud_reading() -> String:
	return "on" if active else "off"


func _on_activated() -> void:
	pass


func _on_deactivated() -> void:
	pass


func current_room_name() -> String:
	if player and player.house:
		var r := player.house.get_room_at(player.global_position)
		if r:
			return r.display_name
	return ""


## Draw helper: use replacement texture when present, else the placeholder.
func _draw() -> void:
	if _texture:
		draw_texture(_texture, -_texture.get_size() * 0.5)
		return
	_draw_placeholder()


func _draw_placeholder() -> void:
	InkStyle.draw_box(self, Rect2(Vector2(-3, -3), Vector2(8, 6)), InkStyle.fill(&"metal"), 1, InkStyle.DETAIL_WIDTH)
