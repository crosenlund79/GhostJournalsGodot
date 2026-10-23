class_name Doll
extends Interactable
## The doll in the kids' room. Opening or closing the kids'-room door may wake
## it. Awake, it either runs at the investigator (a non-lethal mini jump
## scare) or walks to the nearest radio, switches the music on and walks back
## to its place. It walks the ghost's navigation grid and opens doors.

signal attacked(doll: Doll)
signal started_music(doll: Doll, radio: Radio)
signal woke(doll: Doll, action: StringName)

enum State { SITTING, ATTACKING, TO_RADIO, RETURNING }

const TEXTURE_PATH := "res://assets/doll/doll.png"
## On-screen height in world pixels (a small doll: under a tile).
const WORLD_HEIGHT := 36.0
const RUN_SPEED := 168.0
const WALK_SPEED := 52.0
const CATCH_RADIUS := 15.0
const ATTACK_TIMEOUT := 7.0
## Chance per door use that the doll wakes, and the rest time afterwards.
const WAKE_CHANCE := 0.4
const COOLDOWN := 40.0
const ATTACK_CHANCE := 0.5

var house: House
var player: Player
var safe_room: SafeRoomController
var home: Vector2
var state: State = State.SITTING
var cooldown: float = 0.0
var wake_chance: float = WAKE_CHANCE
var rng := RandomNumberGenerator.new()

var _texture: Texture2D
var _path := PackedVector2Array()
var _path_index: int = 0
var _repath: float = 0.0
var _state_time: float = 0.0
var _target_radio: Radio
var _pending_door: Door
var _door_wait: float = 0.0
var _time: float = 0.0
var _facing_x: float = 1.0
var _step: float = 0.0


func _ready() -> void:
	prompt_text = "Look at the doll"
	highlight_extent = Vector2(9, 13)
	interaction_range = 40.0
	super._ready()
	add_to_group(&"doll")
	z_index = 4
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if ResourceLoader.exists(TEXTURE_PATH):
		_texture = load(TEXTURE_PATH)
	rng.randomize()
	home = global_position


func setup(world_house: House, target_player: Player, safe: SafeRoomController, kids_room: RoomData) -> void:
	house = world_house
	player = target_player
	safe_room = safe
	# Watch every door of the kids' room.
	for door in house.doors.values():
		var d := door as Door
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if house.get_room_at_cell(d.cell + dir) == kids_room:
				d.door_toggled.connect(_on_door_toggled)
				break


func can_interact(actor: Node) -> bool:
	return super.can_interact(actor) and state == State.SITTING


func interact(actor: Node) -> void:
	var lines := ["Its stitched eyes seem to follow you.", "It's warmer than it should be.", "Someone has been brushing its hair."]
	if player and player.investigation:
		player.investigation.notify(lines[rng.randi() % lines.size()], &"info")
	super.interact(actor)


func is_awake() -> bool:
	return state != State.SITTING


func _on_door_toggled(_door: Door, _open: bool, by_ghost: bool) -> void:
	if by_ghost or state != State.SITTING or cooldown > 0.0:
		return
	if player == null or player.is_dead:
		return
	if rng.randf() < wake_chance:
		wake()


## Wakes the doll. `action` forces &"attack" or &"radio" (tests, debug).
func wake(action: StringName = &"") -> void:
	if state != State.SITTING:
		return
	if action == &"":
		action = &"attack" if rng.randf() < ATTACK_CHANCE else &"radio"
	if action == &"radio":
		_target_radio = _nearest_radio()
		if _target_radio == null:
			action = &"attack"
	AudioManager.play_at(&"giggle", global_position, 2.0, rng.randf_range(0.9, 1.1))
	_state_time = 0.0
	if action == &"attack":
		state = State.ATTACKING
		_repath = 0.0
	else:
		state = State.TO_RADIO
		_set_destination(_target_radio.global_position)
	woke.emit(self, action)


func _nearest_radio() -> Radio:
	var best: Radio = null
	var best_d := INF
	var my_room := house.get_room_at(home)
	for r in house.radios():
		if r.room == my_room or r.is_on:
			continue
		var d := r.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = r
	return best


func _physics_process(delta: float) -> void:
	_time += delta
	if cooldown > 0.0:
		cooldown -= delta
	if house == null:
		return
	_state_time += delta
	match state:
		State.SITTING:
			pass
		State.ATTACKING:
			_process_attack(delta)
		State.TO_RADIO:
			_move(WALK_SPEED, delta)
			if not _has_path() and _pending_door == null:
				if _target_radio and _target_radio.set_on(true, &"doll"):
					started_music.emit(self, _target_radio)
				_go_home()
		State.RETURNING:
			_move(WALK_SPEED, delta)
			if not _has_path() and _pending_door == null:
				global_position = home
				state = State.SITTING
				cooldown = COOLDOWN
	queue_redraw()


func _process_attack(delta: float) -> void:
	var can_reach := player != null and not player.is_dead and house.is_indoors(player.global_position) \
		and not (safe_room and safe_room.is_position_protected(player.global_position))
	if not can_reach or _state_time > ATTACK_TIMEOUT:
		_go_home()
		return
	_repath -= delta
	if _repath <= 0.0:
		_repath = 0.3
		_set_destination(player.global_position)
	_move(RUN_SPEED, delta)
	if global_position.distance_to(player.global_position) < InkStyle.TILE:
		global_position = global_position.move_toward(player.global_position, RUN_SPEED * delta)
	if global_position.distance_to(player.global_position) < CATCH_RADIUS:
		attacked.emit(self)
		_go_home()


func _go_home() -> void:
	state = State.RETURNING
	_set_destination(home)


func _set_destination(world_position: Vector2) -> void:
	_path = house.find_path(global_position, world_position)
	_path_index = 0
	if _path.size() > 1 and _path[0].distance_to(global_position) < InkStyle.TILE * 0.75:
		_path_index = 1


func _has_path() -> bool:
	return _path_index < _path.size()


func _move(speed: float, delta: float) -> void:
	if _pending_door:
		_door_wait -= delta
		if _door_wait <= 0.0:
			if not _pending_door.locked:
				_pending_door.set_open(true, true)
			else:
				_path_index = _path.size()
			_pending_door = null
		return
	if not _has_path():
		return
	var target := _path[_path_index]
	var door := house.door_at(house.world_to_cell(target))
	if door and not door.is_open:
		_pending_door = door
		_door_wait = 0.35
		return
	var to := target - global_position
	if absf(to.x) > 0.5:
		_facing_x = signf(to.x)
	global_position = global_position.move_toward(target, speed * delta)
	if global_position.distance_to(target) < 1.0:
		_path_index += 1
	# Tiny, quick footsteps.
	_step += speed * delta
	if _step > (22.0 if speed > 100.0 else 16.0):
		_step = 0.0
		AudioManager.play_at(&"footstep", global_position, -10.0, 1.9, 420.0)


func _draw() -> void:
	var moving := state != State.SITTING
	var waddle := sin(_time * (22.0 if state == State.ATTACKING else 9.0)) * (0.16 if moving else 0.0)
	var bob := absf(sin(_time * (22.0 if state == State.ATTACKING else 9.0))) * (-2.0 if moving else 0.0)
	var tilt := waddle if moving else -0.12
	if _texture:
		var size := _texture.get_size() * (WORLD_HEIGHT / _texture.get_size().y)
		draw_set_transform(Vector2(0, bob), tilt, Vector2(_facing_x, 1.0))
		draw_texture_rect(_texture, Rect2(-size * 0.5, size), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		InkStyle.draw_oval(self, Vector2(0, -6), Vector2(5, 5), InkStyle.PAPER_MUTED, 9101)
		InkStyle.draw_box(self, Rect2(Vector2(-5, -1), Vector2(10, 12)), InkStyle.RUST, 9102)
