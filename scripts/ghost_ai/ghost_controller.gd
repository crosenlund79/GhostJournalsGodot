class_name GhostController
extends Node2D
## Shared ghost behaviour driven by a [GhostDefinition].
##
## State machine: DORMANT -> ROAMING <-> INTERACTING / MANIFESTING,
## HUNTING (started by [HuntDirector]) -> RECOVERING -> ROAMING, BANISHED.
## Navigation runs on the house's AStarGrid2D. The ghost is invisible except
## while manifesting or hunting, and even then only when the player can
## actually perceive it (facing, line of sight, light).

signal state_changed(new_state: int)
signal interaction_performed(kind: StringName, world_position: Vector2)
signal manifested(seen: bool)
signal player_caught
signal banished

enum State { DORMANT, ROAMING, INTERACTING, MANIFESTING, HUNTING, RECOVERING, BANISHED }
const STATE_NAMES := ["Dormant", "Roaming", "Interacting", "Manifesting", "Hunting", "Recovering", "Banished"]

const TILE := InkStyle.TILE
const CATCH_RADIUS := 15.0
const HUNT_SIGHT_RANGE := 420.0
## During a hunt the ghost senses the player this close even without sight.
const HUNT_SENSE_RANGE := 70.0
const SPIRIT_BOX_RANGE := 230.0
const LOS_MASK := 1

var definition: GhostDefinition
var balance: GameBalance
var house: House
var player: Player
var electrical: ElectricalSystem
var investigation: InvestigationManager
var safe_room: SafeRoomController
## Parent for spawned evidence (EMF sources, UV prints, orbs).
var evidence_root: Node2D

var state: State = State.DORMANT
var favorite_room: RoomData
var current_room: RoomData
var rng := RandomNumberGenerator.new()
var visual: GhostVisual
## How visible the ghost currently is to the player (0..1).
var perceived_amount: float = 0.0
## > 0 while a ritual is being performed nearby (raises aggression).
var ritual_provocation: float = 0.0
var debug_reveal: bool = false
## Tutorial ghosts behave normally but a catch is never fatal.
var harmless: bool = false
var trail: SmokeTrail
var _last_position := Vector2.ZERO
var _trail_distance: float = 0.0
var caught_player: bool = false
var facing: Vector2 = Vector2.DOWN

var _path := PackedVector2Array()
var _path_index: int = 0
var _state_timer: float = 0.0
var _idle_timer: float = 0.0
var _interaction_timer: float = 0.0
var _manifest_timer: float = 0.0
var _whisper_timer: float = 0.0
var _pending_door: Door
var _door_wait: float = 0.0
var _manifest_seen: bool = false
var _hunt_grace: float = 0.0
var _hunt_repath: float = 0.0
var _chasing: bool = false
var _sees_player: bool = false
var _last_known := Vector2.ZERO
var _flicker_timer: float = 0.0
var _flicker_on: bool = false
var _orbs: Array[GhostOrb] = []
var _step_timer: float = 0.0


func setup(def: GhostDefinition, game_balance: GameBalance, world_house: House, target_player: Player,
		electrical_system: ElectricalSystem, manager: InvestigationManager, safe: SafeRoomController,
		evidence_parent: Node2D, seed_value: int = -1) -> void:
	definition = def
	balance = game_balance
	house = world_house
	player = target_player
	electrical = electrical_system
	investigation = manager
	safe_room = safe
	evidence_root = evidence_parent
	visual.scale = Vector2.ONE * 1.45 * definition.silhouette_scale
	if definition.sprite:
		visual.set_token(definition.sprite, definition.sprite_world_height)
	trail.enabled = definition.smoke_trail
	trail.player = target_player
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	favorite_room = _choose_favorite_room()
	var cell := house.random_walkable_cell(favorite_room, rng)
	global_position = house.cell_to_world(cell)
	current_room = favorite_room
	_state_timer = balance.dormant_duration
	_interaction_timer = rng.randf_range(definition.interaction_interval.x, definition.interaction_interval.y) * 0.5
	_manifest_timer = balance.manifestation_check_interval
	_whisper_timer = rng.randf_range(definition.whisper_interval.x, definition.whisper_interval.y)
	if definition.has_evidence(&"orbs"):
		for i in 2:
			var orb := GhostOrb.new()
			orb.house = house
			orb.room = favorite_room
			evidence_root.add_child(orb)
			orb.global_position = house.cell_to_world(house.random_walkable_cell(favorite_room, rng))
			_orbs.append(orb)


func _ready() -> void:
	add_to_group(&"ghost")
	z_index = 6
	material = InkStyle.unshaded_material()
	visual = GhostVisual.new()
	visual.name = "Visual"
	visual.modulate.a = 0.0
	visual.scale = Vector2.ONE * 1.45
	add_child(visual)
	# The trail lives beside the ghost (not under it) so puffs stay behind.
	trail = SmokeTrail.new()
	trail.name = "GhostSmokeTrail"
	trail.z_index = z_index - 1
	get_parent().add_child.call_deferred(trail)
	_last_position = global_position


func _choose_favorite_room() -> RoomData:
	var candidates: Array[RoomData] = []
	var weights: Array[float] = []
	var total := 0.0
	for r in house.indoor_rooms():
		if not r.can_be_favorite:
			continue
		var darkness := clampf(1.1 - r.light_energy, 0.0, 1.0)
		var w := 1.0 + definition.darkness_preference * darkness * 6.0
		candidates.append(r)
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	for i in candidates.size():
		roll -= weights[i]
		if roll <= 0.0:
			return candidates[i]
	return candidates.back()


# --- Queries ------------------------------------------------------------------

func is_active() -> bool:
	return state != State.BANISHED


func is_hunting() -> bool:
	return state == State.HUNTING


func state_name() -> String:
	return STATE_NAMES[state]


func activity_multiplier() -> float:
	var m := balance.activity_multiplier(player.sanity.value) if player else 1.0
	if is_player_near():
		m *= definition.proximity_aggression
	return m * (1.0 + ritual_provocation)


func is_player_near() -> bool:
	if player == null or player.is_dead:
		return false
	var player_room := house.get_room_at(player.global_position)
	return (player_room != null and player_room == current_room) or player.global_position.distance_to(global_position) < 5.0 * TILE


func has_line_of_sight_to(point: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	return space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, point, LOS_MASK)).is_empty()


# --- Main loop ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if house == null:
		return
	match state:
		State.DORMANT:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_set_state(State.ROAMING)
		State.ROAMING:
			_process_roaming(delta, true)
		State.RECOVERING:
			_process_roaming(delta, false)
			_state_timer -= delta
			if _state_timer <= 0.0:
				_set_state(State.ROAMING)
		State.INTERACTING:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_set_state(State.ROAMING)
		State.MANIFESTING:
			_process_manifesting(delta)
		State.HUNTING:
			_process_hunting(delta)
		State.BANISHED:
			pass
	var room := house.get_room_at(global_position)
	if room:
		current_room = room
	_update_visibility(delta)


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)


func _process_roaming(delta: float, allow_events: bool) -> void:
	if _pending_door:
		_wait_for_door(delta)
	elif _path_index < _path.size():
		_follow_path(definition.roam_speed, delta)
	else:
		_idle_timer -= delta
		if _idle_timer <= 0.0:
			_choose_roam_destination()
	var mult := activity_multiplier()
	_interaction_timer -= delta * mult * (1.0 if allow_events else 0.5)
	if _interaction_timer <= 0.0:
		_interaction_timer = rng.randf_range(definition.interaction_interval.x, definition.interaction_interval.y)
		perform_interaction()
		return
	if not allow_events:
		return
	_manifest_timer -= delta
	if _manifest_timer <= 0.0:
		_manifest_timer = balance.manifestation_check_interval
		_try_manifest()
	if definition.whisper_interval.x > 0.0:
		_whisper_timer -= delta
		if _whisper_timer <= 0.0:
			_whisper_timer = rng.randf_range(definition.whisper_interval.x, definition.whisper_interval.y)
			if player and player.global_position.distance_to(global_position) < 320.0:
				AudioManager.play_at(&"whisper", global_position, 0.0, definition.voice_pitch)


func _choose_roam_destination() -> void:
	var room := favorite_room
	if rng.randf() > definition.favorite_room_bias:
		var pool: Array[RoomData] = favorite_room.neighbors.duplicate()
		if current_room:
			pool.append_array(current_room.neighbors)
		var options: Array[RoomData] = []
		for r in pool:
			if not r.is_outdoors and not house.is_room_blocked(r):
				options.append(r)
		if not options.is_empty():
			room = options[rng.randi() % options.size()]
	var cell := house.random_walkable_cell(room, rng)
	_idle_timer = rng.randf_range(1.5, 5.0)
	if cell.x >= 0:
		set_destination(house.cell_to_world(cell))


func set_destination(world_position: Vector2) -> void:
	_path = house.find_path(global_position, world_position)
	_path_index = 0
	if _path.size() > 1 and _path[0].distance_to(global_position) < TILE * 0.75:
		_path_index = 1


func has_path() -> bool:
	return _path_index < _path.size()


func _follow_path(speed: float, delta: float) -> void:
	if _path_index >= _path.size():
		return
	var target := _path[_path_index]
	var door := house.door_at(house.world_to_cell(target))
	if door and not door.is_open:
		_pending_door = door
		_door_wait = 0.55 if state == State.HUNTING else 0.9
		return
	var to := target - global_position
	if to.length() > 0.5:
		facing = to.normalized()
	global_position = global_position.move_toward(target, speed * delta)
	if global_position.distance_to(target) < 1.0:
		_path_index += 1


func _wait_for_door(delta: float) -> void:
	_door_wait -= delta
	if _door_wait > 0.0:
		return
	var door := _pending_door
	_pending_door = null
	if door.locked:
		door.ghost_toggle()
		_path_index = _path.size()
		return
	door.set_open(true, true)
	_leave_evidence_at(door.global_position, true)


# --- Interactions & evidence --------------------------------------------------

## Chooses and performs one environmental interaction, leaving evidence
## according to the ghost's definition.
func perform_interaction() -> StringName:
	if player == null:
		return &""
	var kinds: Array[StringName] = []
	var weights: Array[float] = []
	var doors := house.doors_near(global_position, 4.5 * TILE)
	if not doors.is_empty():
		kinds.append(&"door")
		weights.append(definition.door_weight)
	if current_room and not current_room.lights.is_empty() and house.is_power_on():
		kinds.append(&"light")
		weights.append(definition.light_weight * (1.0 if current_room.light_switch_on else 0.3))
	kinds.append(&"object")
	weights.append(definition.object_weight)
	var book := _nearest_unwritten_book()
	if book and definition.has_evidence(&"writing"):
		kinds.append(&"writing")
		weights.append(2.0)
	var appliance := _nearest_appliance()
	if appliance:
		kinds.append(&"appliance")
		weights.append(definition.appliance_weight)
	if house.is_power_on():
		kinds.append(&"power")
		weights.append(definition.power_trip_weight)
	var kind := _weighted_pick(kinds, weights)
	var pos := global_position
	match kind:
		&"door":
			var door: Door = doors[rng.randi() % doors.size()]
			door.ghost_toggle()
			pos = door.global_position
			_leave_evidence_at(pos, true)
		&"light":
			var on := not current_room.light_switch_on
			house.set_room_light(current_room, on)
			pos = house.cell_to_world(current_room.switch_cell) if current_room.switch_cell.x >= 0 else global_position
			AudioManager.play_at(&"switch", pos, 0.0)
			_leave_evidence_at(pos, rng.randf() < 0.5)
		&"object":
			pos = global_position + Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12))
			AudioManager.play_at(&"knock", pos, 2.0, rng.randf_range(0.8, 1.2))
			_leave_evidence_at(pos, false)
		&"writing":
			if rng.randf() < definition.writing_chance:
				book.write()
			pos = book.global_position
			_leave_evidence_at(pos, false)
		&"appliance":
			appliance.toggle(&"ghost")
			pos = appliance.global_position
			_leave_evidence_at(pos, true)
		&"power":
			electrical.trip("ghost")
			_leave_evidence_at(pos, false)
	if player.house.is_indoors(player.global_position) and \
			(house.get_room_at(player.global_position) == house.get_room_at(pos) or player.perceive(pos) > 0.2):
		player.sanity.apply_loss(balance.event_witness_loss)
	_set_state(State.INTERACTING)
	_state_timer = 1.2
	interaction_performed.emit(kind, pos)
	return kind


func _weighted_pick(kinds: Array[StringName], weights: Array[float]) -> StringName:
	var total := 0.0
	for w in weights:
		total += w
	var roll := rng.randf() * total
	for i in kinds.size():
		roll -= weights[i]
		if roll <= 0.0:
			return kinds[i]
	return kinds.back()


func _nearest_appliance() -> Appliance:
	var best: Appliance = null
	var best_d := 5.0 * TILE
	for node in get_tree().get_nodes_in_group(&"appliance"):
		var a := node as Appliance
		if a == null:
			continue
		var d := a.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = a
	return best


func _nearest_unwritten_book() -> WritingBook:
	var best: WritingBook = null
	var best_d := 5.0 * TILE
	for node in get_tree().get_nodes_in_group(&"writing_book"):
		var b := node as WritingBook
		if b and not b.written:
			var d := b.global_position.distance_to(global_position)
			if d < best_d:
				best_d = d
				best = b
	return best


func _leave_evidence_at(pos: Vector2, touchable: bool) -> void:
	var level := rng.randi_range(2, 4)
	if definition.has_evidence(&"emf_5") and rng.randf() < definition.emf5_chance:
		level = 5
	EmfSource.spawn(evidence_root, pos, level, 22.0)
	if touchable and definition.has_evidence(&"uv_prints") and rng.randf() < definition.uv_print_chance:
		spawn_uv_print(pos)


func spawn_uv_print(pos: Vector2) -> UvPrint:
	var p := UvPrint.new()
	var room := house.get_room_at(pos)
	if room == null:
		room = current_room
	p.room_name = room.display_name if room else ""
	evidence_root.add_child(p)
	p.global_position = pos + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6))
	return p


func try_spirit_box_response(p: Player) -> String:
	if not definition.has_evidence(&"spirit_box"):
		return ""
	if state == State.BANISHED or state == State.HUNTING or state == State.DORMANT:
		return ""
	var room := house.get_room_at(p.global_position)
	if room == null or room.is_outdoors or house.is_room_lit(room):
		return ""
	if p.global_position.distance_to(global_position) > SPIRIT_BOX_RANGE and room != current_room:
		return ""
	if rng.randf() > definition.spirit_box_chance:
		return ""
	return definition.spirit_box_phrases[rng.randi() % definition.spirit_box_phrases.size()]


# --- Manifestation ------------------------------------------------------------

func _try_manifest() -> void:
	if player == null or player.is_dead or not house.is_indoors(player.global_position):
		return
	if safe_room and safe_room.is_position_protected(player.global_position):
		return
	if not is_player_near() and player.global_position.distance_to(global_position) > 9.0 * TILE:
		return
	var chance := definition.manifestation_chance * activity_multiplier()
	if not house.is_point_lit(player.global_position):
		chance += definition.darkness_manifest_bonus
	if rng.randf() < chance:
		start_manifestation()


func start_manifestation() -> void:
	if state == State.BANISHED or state == State.HUNTING:
		return
	_reposition_near_player()
	_set_state(State.MANIFESTING)
	_state_timer = rng.randf_range(2.5, 4.0)
	_manifest_seen = false
	_path = PackedVector2Array()
	_pending_door = null
	AudioManager.play_at(&"manifest", global_position, 1.0, definition.voice_pitch)


func _reposition_near_player() -> void:
	if player == null:
		return
	var d := global_position.distance_to(player.global_position)
	if d < 6.0 * TILE:
		return
	# Appear somewhere in the player's room, keeping some distance.
	var room := house.get_room_at(player.global_position)
	if room == null or house.is_room_blocked(room):
		return
	var options: Array[Vector2i] = []
	for cell in room.cells:
		if not house.is_ghost_walkable(cell):
			continue
		var dist := house.cell_to_world(cell).distance_to(player.global_position)
		if dist > 2.2 * TILE and dist < 5.5 * TILE:
			options.append(cell)
	if not options.is_empty():
		global_position = house.cell_to_world(options[rng.randi() % options.size()])


func _process_manifesting(delta: float) -> void:
	_state_timer -= delta
	if player:
		var to := player.global_position - global_position
		if to.length() > 28.0:
			facing = to.normalized()
			var step := global_position.move_toward(player.global_position, 16.0 * delta)
			if house.is_ghost_walkable(house.world_to_cell(step)):
				global_position = step
	if perceived_amount > 0.3:
		_manifest_seen = true
	if _state_timer <= 0.0:
		_end_manifestation()


func _end_manifestation() -> void:
	if player:
		player.sanity.apply_loss(balance.manifestation_seen_loss if _manifest_seen else balance.manifestation_unseen_loss)
	if _manifest_seen and investigation:
		var room := house.get_room_at(global_position)
		investigation.add_field_note("A dark figure stood in the %s." % (room.display_name if room else "dark"))
	_set_state(State.ROAMING)
	_idle_timer = 1.0
	manifested.emit(_manifest_seen)


# --- Hunting ------------------------------------------------------------------

func begin_hunt() -> void:
	if state == State.BANISHED:
		return
	_set_state(State.HUNTING)
	caught_player = false
	_hunt_grace = balance.hunt_grace_period
	_hunt_repath = 0.0
	_chasing = false
	_sees_player = false
	_path = PackedVector2Array()
	_pending_door = null
	_flicker_on = true
	var cell := house.world_to_cell(global_position)
	if not house.is_ghost_walkable(cell):
		var free := house.nearest_walkable_cell(cell, 20)
		if free.x >= 0:
			global_position = house.cell_to_world(free)


func end_hunt() -> void:
	if state != State.HUNTING:
		return
	_set_state(State.RECOVERING)
	_state_timer = 20.0
	_path = PackedVector2Array()
	_pending_door = null
	_chasing = false


func can_target_player() -> bool:
	if player == null or player.is_dead:
		return false
	if not house.is_indoors(player.global_position):
		return false
	if safe_room and safe_room.is_position_protected(player.global_position):
		return false
	return true


func _process_hunting(delta: float) -> void:
	if caught_player:
		return
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		_flicker_on = not _flicker_on
		_flicker_timer = rng.randf_range(0.12, 0.4) if _flicker_on else rng.randf_range(0.05, 0.25)
	if _hunt_grace > 0.0:
		_hunt_grace -= delta
		return
	var can_target := can_target_player()
	var dist := player.global_position.distance_to(global_position) if player else INF
	_hunt_repath -= delta
	if _hunt_repath <= 0.0:
		_hunt_repath = 0.25
		_sees_player = can_target and (dist < HUNT_SENSE_RANGE or (dist < HUNT_SIGHT_RANGE and has_line_of_sight_to(player.global_position)))
		if _sees_player:
			_chasing = true
			_last_known = player.global_position
			set_destination(_last_known)
		elif not has_path() and _pending_door == null:
			_chasing = false
			_search()
	# Heavy footsteps betray the hunter's position.
	_step_timer -= delta
	if _step_timer <= 0.0 and has_path():
		_step_timer = 0.38 if _sees_player else 0.5
		AudioManager.play_at(&"footstep", global_position, 6.0, 0.55 * definition.voice_pitch, 520.0)
	if _pending_door:
		_wait_for_door(delta)
	else:
		var speed := definition.hunt_speed * (definition.hunt_seen_speed_multiplier if _sees_player else 1.0)
		_follow_path(speed, delta)
		# Close the final gap directly once the player is in reach.
		if _sees_player and dist < TILE * 1.2:
			global_position = global_position.move_toward(player.global_position, speed * delta)
	if can_target and player.global_position.distance_to(global_position) < CATCH_RADIUS:
		_catch_player()


func _search() -> void:
	var room: RoomData = house.get_room_at(_last_known) if _last_known != Vector2.ZERO else current_room
	if room == null or room.is_outdoors or house.is_room_blocked(room):
		room = current_room
	if rng.randf() < 0.5 and room and not room.neighbors.is_empty():
		var n: RoomData = room.neighbors[rng.randi() % room.neighbors.size()]
		if not n.is_outdoors and not house.is_room_blocked(n):
			room = n
	if room == null:
		return
	var cell := house.random_walkable_cell(room, rng)
	if cell.x >= 0:
		set_destination(house.cell_to_world(cell))


func _catch_player() -> void:
	caught_player = true
	# With a splash image the jump scare plays on screen instead.
	if definition.caught_sprite == null:
		visual.set_horror(true)
	if player:
		facing = (player.global_position - global_position).normalized()
	player_caught.emit()


## Lets go of a caught player (harmless ghosts only) and resumes normal behaviour.
func release_player() -> void:
	caught_player = false
	visual.set_horror(false)


# --- Banishment ---------------------------------------------------------------

func banish() -> void:
	if state == State.BANISHED:
		return
	_set_state(State.BANISHED)
	AudioManager.play_at(&"banish", global_position, 2.0)
	for orb in _orbs:
		if is_instance_valid(orb):
			orb.queue_free()
	_orbs.clear()
	visual.play_banish()
	banished.emit()


# --- Presentation ---------------------------------------------------------------

func _update_visibility(delta: float) -> void:
	var base := 0.0
	match state:
		State.MANIFESTING:
			base = 1.0
		State.HUNTING:
			base = 1.0 if (_flicker_on or caught_player) else 0.0
	var perception := player.perceive(global_position) if player and not player.is_dead else 0.0
	var target := base * perception
	if caught_player:
		target = 1.0
	perceived_amount = target
	var shown := maxf(target, 0.35 if debug_reveal and state != State.BANISHED else 0.0)
	if state == State.BANISHED:
		shown = visual.modulate.a
	visual.modulate.a = move_toward(visual.modulate.a, shown, delta * (14.0 if state == State.HUNTING else 5.0))
	visual.rotation = 0.0 if visual.is_upright() else facing.angle()
	visual.facing = facing
	_update_trail()
	queue_redraw()


## Emits smoke along the path while the ghost is visible and moving.
func _update_trail() -> void:
	var moved := global_position.distance_to(_last_position)
	var from := _last_position
	_last_position = global_position
	# Teleports (e.g. appearing near the player) leave no trail.
	if moved > TILE or trail == null or not trail.is_inside_tree():
		return
	if visual.modulate.a < 0.08 or moved < 0.05:
		_trail_distance = 0.0
		return
	_trail_distance += moved
	var back := (global_position - from).normalized()
	while _trail_distance >= SmokeTrail.SPACING:
		_trail_distance -= SmokeTrail.SPACING
		var pos := global_position - back * (_trail_distance + 6.0) + Vector2(0, 12.0)
		trail.emit_puff(pos, -back, visual.modulate.a)


func _draw() -> void:
	if not (GameManager.debug_enabled and DebugFlags.show_world_debug):
		return
	draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 20, Color(1, 0.2, 0.2, 0.9), 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(-20, -16), state_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.4, 0.4))
	for i in range(_path_index, _path.size()):
		draw_circle(to_local(_path[i]), 1.5, Color(1, 0.3, 0.3, 0.6))
