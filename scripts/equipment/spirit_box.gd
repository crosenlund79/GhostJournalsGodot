class_name SpiritBox
extends Equipment
## Radio sweep that a compatible ghost can answer through. While switched on
## it plays static and periodically "asks"; a response requires a ghost with
## "Spirit Box Response" evidence, close by, with the room's lights off.

const QUERY_INTERVAL := 3.2
const RESPONSE_RANGE := 230.0

var last_response: String = ""
var _query_timer: float = 2.0
var _response_timer: float = 0.0
var _sweep: float = 88.1


func _on_activated() -> void:
	AudioManager.start_loop(&"spirit_box", &"static_loop", -16.0)
	_query_timer = QUERY_INTERVAL


func _on_deactivated() -> void:
	AudioManager.stop_loop(&"spirit_box")


func _exit_tree() -> void:
	AudioManager.stop_loop(&"spirit_box")


func _process(delta: float) -> void:
	if not active:
		return
	_sweep = 87.5 + fmod(_sweep - 87.5 + delta * 2.7, 20.5)
	if _response_timer > 0.0:
		_response_timer -= delta
	_query_timer -= delta
	if _query_timer <= 0.0:
		_query_timer = QUERY_INTERVAL
		_ask()
	state_changed.emit(self)


func _ask() -> void:
	if player == null or player.ghost == null:
		return
	var phrase := player.ghost.try_spirit_box_response(player)
	if phrase == "":
		return
	last_response = phrase
	_response_timer = 3.0
	AudioManager.play(&"ghost_voice", -2.0, player.ghost.definition.voice_pitch)
	if player.investigation:
		player.investigation.observe(&"spirit_box", current_room_name(), phrase)
		player.investigation.notify("The static breaks: \"%s\"" % phrase, &"evidence")
	if player.balance:
		player.sanity.apply_loss(player.balance.spirit_box_response_loss)


## Forces a response (debug tooling).
func debug_force_response(phrase: String) -> void:
	last_response = phrase
	_response_timer = 3.0


func get_hud_reading() -> String:
	if not active:
		return "off"
	if _response_timer > 0.0:
		return "\"%s\"" % last_response
	return "sweeping %.1f FM" % _sweep


func _draw_placeholder() -> void:
	InkStyle.draw_box(self, Rect2(Vector2(-5, -4), Vector2(11, 8)), InkStyle.RUST.darkened(0.4), 41, InkStyle.DETAIL_WIDTH)
	draw_line(Vector2(5, -3), Vector2(10, -6), InkStyle.INK, InkStyle.DETAIL_WIDTH)
