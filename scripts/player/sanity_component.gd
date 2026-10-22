class_name SanityComponent
extends Node
## Player sanity (0..100). Continuous drain depends on light; shocks come from
## ghost events. See [GameBalance] for every tunable number.

signal sanity_changed(value: float)

var value: float = 100.0
var balance: GameBalance
var player: Player
## Last per-second rate, exposed for the debug overlay.
var current_rate: float = 0.0


func _physics_process(delta: float) -> void:
	if player == null or balance == null or player.is_dead or player.house == null:
		return
	current_rate = compute_rate()
	if current_rate != 0.0:
		set_value(value + current_rate * delta)


## Per-second change from the player's current situation.
func compute_rate() -> float:
	var house := player.house
	if not house.is_indoors(player.global_position):
		return 0.0
	if player.safe_room and player.safe_room.is_position_protected(player.global_position):
		return balance.safe_room_recovery
	var rate := 0.0
	var room := house.get_room_at(player.global_position)
	if not house.is_room_lit(room):
		var drain := balance.flashlight_darkness_drain if player.has_handheld_light() else balance.darkness_drain
		if not house.is_power_on():
			drain *= balance.power_out_multiplier
		rate -= drain
	var ghost := player.ghost
	if ghost and ghost.is_active() and not ghost.is_hunting():
		if ghost.global_position.distance_to(player.global_position) < balance.ghost_proximity_radius:
			rate -= balance.ghost_proximity_drain
	return rate


func apply_loss(amount: float) -> void:
	set_value(value - amount)


func set_value(v: float) -> void:
	var clamped := clampf(v, 0.0, 100.0)
	if is_equal_approx(clamped, value):
		value = clamped
		return
	value = clamped
	sanity_changed.emit(value)
