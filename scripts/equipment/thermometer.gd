class_name Thermometer
extends Equipment
## Reads the temperature of the room the investigator stands in.
## A reading below 0 °C is evidence ("Freezing Temperatures").

const SAMPLE_INTERVAL := 0.6

var reading: float = 0.0
var _timer: float = 0.0


func _on_activated() -> void:
	_timer = 0.0


func _physics_process(delta: float) -> void:
	if not active or player == null or player.temperature == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = SAMPLE_INTERVAL
	reading = player.temperature.get_temperature_at(player.global_position) + randf_range(-0.4, 0.4)
	if reading < 0.0 and player.investigation:
		player.investigation.observe(&"freezing", current_room_name(), "%.1f °C" % reading)
	state_changed.emit(self)


func get_hud_reading() -> String:
	return "%.1f °C" % reading if active else "off"


func _draw_placeholder() -> void:
	InkStyle.draw_box(self, Rect2(Vector2(-4, -2.5), Vector2(10, 5)), InkStyle.PAPER_MUTED, 61, InkStyle.DETAIL_WIDTH)
	draw_circle(Vector2(-3, 0), 1.2, InkStyle.BLOOD)
