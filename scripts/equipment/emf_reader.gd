class_name EmfReader
extends Equipment
## Shows the strongest nearby electromagnetic disturbance (levels 0-5).
## A level 5 reading is evidence ("EMF Level 5").

const DETECTION_RADIUS := 105.0
const SAMPLE_INTERVAL := 0.2

var level: int = 0
var _sample_timer: float = 0.0
var _beep_timer: float = 0.0
var _led: Array[StatusLed] = []


func _ready() -> void:
	super._ready()
	for i in 5:
		var led := StatusLed.new()
		led.radius = 1.0
		led.position = Vector2(-4 + i * 2.4, -1.5)
		led.visible = false
		add_child(led)
		_led.append(led)


func _physics_process(delta: float) -> void:
	if not active:
		return
	_sample_timer -= delta
	if _sample_timer <= 0.0:
		_sample_timer = SAMPLE_INTERVAL
		level = sample_level(global_position)
		_update_leds()
		if level >= 5 and player and player.investigation:
			player.investigation.observe(&"emf_5", current_room_name())
	if level >= 2:
		_beep_timer -= delta
		if _beep_timer <= 0.0:
			_beep_timer = 0.75 - level * 0.12
			AudioManager.play(&"emf_beep", -14.0 + level * 2.0, 0.85 + level * 0.08)


func sample_level(at: Vector2) -> int:
	var best := 0
	for node in get_tree().get_nodes_in_group(&"emf_source"):
		var src := node as EmfSource
		if src and src.global_position.distance_to(at) <= DETECTION_RADIUS:
			best = maxi(best, src.level)
	# Baseline flicker from the ghost's own presence.
	if best == 0 and player and player.ghost and player.ghost.is_active() \
			and player.ghost.global_position.distance_to(at) < DETECTION_RADIUS * 0.8:
		best = 1
	return best


func _on_deactivated() -> void:
	level = 0
	_update_leds()


func _update_leds() -> void:
	for i in _led.size():
		var led := _led[i]
		led.visible = active and i < level
		led.color = InkStyle.SICK_GREEN.lightened(0.3) if i < 3 else (InkStyle.LIGHT_WARD if i < 4 else InkStyle.BLOOD.lightened(0.4))
		led.queue_redraw()


func get_hud_reading() -> String:
	if not active:
		return "off"
	var bars := ""
	for i in 5:
		bars += "■" if i < level else "·"
	return "%s  %d" % [bars, level]


func _draw_placeholder() -> void:
	InkStyle.draw_box(self, Rect2(Vector2(-6, -4), Vector2(12, 8)), InkStyle.PAPER_DARK, 31, InkStyle.DETAIL_WIDTH)
