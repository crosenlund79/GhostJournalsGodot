class_name HuntDirector
extends Node
## Decides when hunts begin and orchestrates them: hunt duration, flickering
## lights, the locked front door, power disruption and hunt audio.

signal hunt_started
signal hunt_ended

var ghost: GhostController
var player: Player
var house: House
var electrical: ElectricalSystem
var lighting: LightingController
var balance: GameBalance
var is_hunting: bool = false
var hunt_time_left: float = 0.0
var cooldown: float = 0.0
var enabled: bool = true
var _check_timer: float = 0.0
var _growl_timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func setup(ghost_controller: GhostController, target_player: Player, world_house: House,
		electrical_system: ElectricalSystem, lighting_controller: LightingController, game_balance: GameBalance) -> void:
	ghost = ghost_controller
	player = target_player
	house = world_house
	electrical = electrical_system
	lighting = lighting_controller
	balance = game_balance
	_rng.randomize()
	_check_timer = balance.hunt_check_interval
	cooldown = balance.first_hunt_delay


func _process(delta: float) -> void:
	if ghost == null or not enabled:
		return
	if is_hunting:
		if ghost.caught_player:
			return
		_update_hunt_audio(delta)
		hunt_time_left -= delta
		if hunt_time_left <= 0.0 or not ghost.is_active():
			end_hunt()
		return
	cooldown -= delta
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = balance.hunt_check_interval
	if should_start_hunt(_rng.randf()):
		start_hunt()


## Hunt rule (documented in README): possible only when the ghost roams,
## the cooldown has passed, the player is inside, and sanity is at or below
## the ghost's threshold. Chance rises as sanity falls below the threshold,
## with the ghost's proximity aggression and during a ritual.
func hunt_chance() -> float:
	if ghost.state != GhostController.State.ROAMING or cooldown > 0.0:
		return 0.0
	if player.is_dead or not house.is_indoors(player.global_position):
		return 0.0
	var def := ghost.definition
	var sanity := player.sanity.value
	var threshold := def.hunt_sanity_threshold + ghost.ritual_provocation * 20.0
	if sanity > threshold:
		return 0.0
	var depth := (threshold - sanity) / maxf(threshold, 1.0)
	var chance := def.hunt_chance * (1.0 + depth * 1.5)
	if ghost.is_player_near():
		chance *= def.proximity_aggression
	return clampf(chance * (1.0 + ghost.ritual_provocation), 0.0, 0.95)


## The closer the hunter, the louder and faster the heartbeat; it growls and
## rasps nearby, and the drone swells.
func _update_hunt_audio(delta: float) -> void:
	var dist := ghost.global_position.distance_to(player.global_position)
	var near := 1.0 - clampf((dist - 40.0) / 460.0, 0.0, 1.0)
	AudioManager.set_loop_volume(&"hunt", lerpf(-10.0, 3.0, near))
	AudioManager.set_loop_pitch(&"hunt", lerpf(0.9, 1.75, near))
	AudioManager.set_loop_volume(&"hunt_drone", lerpf(-8.0, 0.0, near))
	_growl_timer -= delta
	if _growl_timer <= 0.0:
		_growl_timer = _rng.randf_range(1.4, 3.2)
		AudioManager.play_at(&"growl", ghost.global_position, 4.0, _rng.randf_range(0.8, 1.1) * ghost.definition.voice_pitch, 650.0)


func _stop_hunt_audio() -> void:
	AudioManager.stop_loop(&"hunt")
	AudioManager.stop_loop(&"hunt_drone")
	AudioManager.set_hunt_mix(false)


func should_start_hunt(roll: float) -> bool:
	return roll < hunt_chance()


func start_hunt() -> void:
	if is_hunting or not ghost.is_active():
		return
	is_hunting = true
	var def := ghost.definition
	hunt_time_left = _rng.randf_range(def.hunt_duration.x, def.hunt_duration.y)
	ghost.begin_hunt()
	if house.front_door:
		house.front_door.set_locked(true)
	lighting.set_flicker(true)
	if electrical.is_powered() and _rng.randf() < def.hunt_power_trip_chance:
		electrical.trip("hunt")
	AudioManager.play(&"hunt_start", 0.0)
	AudioManager.start_loop(&"hunt", &"heartbeat_loop", -6.0)
	AudioManager.start_loop(&"hunt_drone", &"hunt_drone", -4.0)
	AudioManager.set_hunt_mix(true)
	_growl_timer = 1.0
	player.sanity.apply_loss(balance.hunt_start_loss)
	hunt_started.emit()


func end_hunt() -> void:
	if not is_hunting:
		return
	is_hunting = false
	ghost.end_hunt()
	if house.front_door:
		house.front_door.set_locked(false)
	lighting.set_flicker(false)
	_stop_hunt_audio()
	cooldown = balance.hunt_cooldown
	hunt_ended.emit()


## Immediately stops everything (player death, end of investigation).
func shutdown() -> void:
	enabled = false
	if is_hunting:
		is_hunting = false
		lighting.set_flicker(false)
		_stop_hunt_audio()
		if house.front_door:
			house.front_door.set_locked(false)
