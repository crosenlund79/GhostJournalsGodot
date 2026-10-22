class_name Player
extends CharacterBody2D
## The investigator. Owns movement/facing and wires its components
## (sanity, inventory, interaction). World references are injected by the
## investigation scene.

signal died
signal room_changed(room: RoomData)
signal drop_requested(def: EquipmentDefinition, world_position: Vector2)

const RADIUS := 8.5
const VIEW_HALF_ANGLE := deg_to_rad(68.0)
const LOS_MASK := 1

var house: House
var ghost: GhostController
var safe_room: SafeRoomController
var investigation: InvestigationManager
var temperature: TemperatureSystem
var balance: GameBalance

var input_enabled: bool = true
## Set by UI overlays (journal) to freeze the investigator in place.
var ui_blocked: bool = false
var is_dead: bool = false
var facing: Vector2 = Vector2.RIGHT
## Tests / future gamepad support can steer aim without a mouse.
var aim_override: Vector2 = Vector2.ZERO
var move_override: Vector2 = Vector2.ZERO
var current_room: RoomData
var stamina: float = 1.0
var is_sprinting: bool = false

var sanity: SanityComponent
var equipment: EquipmentManager
var interaction: InteractionSystem
var anchor: Node2D
var camera: Camera2D
var visual: PlayerVisual
var _self_light: PointLight2D
var _step_distance: float = 0.0
var _exhausted: bool = false


func _ready() -> void:
	add_to_group(&"player")
	collision_layer = 4
	collision_mask = House.WALL_LAYER | House.FURNITURE_LAYER
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	z_index = 5
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)

	visual = PlayerVisual.new()
	visual.name = "Visual"
	add_child(visual)
	anchor = Node2D.new()
	anchor.name = "EquipmentAnchor"
	anchor.z_index = 1
	add_child(anchor)

	camera = Camera2D.new()
	camera.name = "Camera"
	camera.zoom = Vector2(2.0, 2.0)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	add_child(camera)

	# A faint personal glow so the investigator never fully vanishes.
	_self_light = PointLight2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	_self_light.texture = tex
	_self_light.texture_scale = 1.1
	_self_light.energy = 0.35
	_self_light.color = Color(0.75, 0.75, 0.85)
	_self_light.shadow_enabled = true
	add_child(_self_light)

	sanity = SanityComponent.new()
	sanity.name = "Sanity"
	sanity.player = self
	add_child(sanity)
	equipment = EquipmentManager.new()
	equipment.name = "Equipment"
	equipment.player = self
	equipment.anchor = anchor
	add_child(equipment)
	interaction = InteractionSystem.new()
	interaction.name = "Interaction"
	interaction.actor = self
	add_child(interaction)


func configure(world_house: House, ghost_controller: GhostController, safe: SafeRoomController,
		manager: InvestigationManager, temps: TemperatureSystem, game_balance: GameBalance) -> void:
	house = world_house
	ghost = ghost_controller
	safe_room = safe
	investigation = manager
	temperature = temps
	balance = game_balance
	sanity.balance = balance
	camera.limit_left = int(-House.TILE * 2)
	camera.limit_top = int(-House.TILE * 2)
	camera.limit_right = int(house.width * House.TILE + House.TILE * 2)
	camera.limit_bottom = int(house.height * House.TILE + House.TILE * 2)


func can_act() -> bool:
	return input_enabled and not ui_blocked and not is_dead


func _physics_process(delta: float) -> void:
	if not can_act():
		velocity = Vector2.ZERO
		return
	var dir := move_override if move_override != Vector2.ZERO else Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var wants_sprint := Input.is_action_pressed(&"sprint") and dir != Vector2.ZERO and not _exhausted
	is_sprinting = wants_sprint and stamina > 0.0
	if is_sprinting:
		stamina = maxf(0.0, stamina - delta / balance.stamina_seconds)
		if stamina <= 0.0:
			_exhausted = true
	else:
		stamina = minf(1.0, stamina + delta * balance.stamina_recovery_per_second)
		if _exhausted and stamina > 0.35:
			_exhausted = false
	var speed := balance.sprint_speed if is_sprinting else balance.walk_speed
	velocity = velocity.move_toward(dir * speed, speed * 10.0 * delta)
	move_and_slide()
	_update_facing(dir)
	_update_room()
	_update_footsteps(delta)


func _update_facing(move_dir: Vector2) -> void:
	var aim := aim_override
	if aim == Vector2.ZERO:
		var to_mouse := get_global_mouse_position() - global_position
		aim = to_mouse if to_mouse.length() > 4.0 else move_dir
	if aim != Vector2.ZERO:
		facing = aim.normalized()
	visual.rotation = facing.angle()
	anchor.rotation = facing.angle()
	anchor.position = facing * 9.0


func _update_room() -> void:
	if house == null:
		return
	var room := house.get_room_at(global_position)
	if room and room != current_room:
		current_room = room
		room_changed.emit(room)


func _update_footsteps(delta: float) -> void:
	var moved := velocity.length() * delta
	if moved <= 0.01:
		return
	_step_distance += moved
	visual.walk_phase += moved * 0.25
	visual.queue_redraw()
	var stride := 30.0 if is_sprinting else 24.0
	if _step_distance >= stride:
		_step_distance = 0.0
		AudioManager.play(&"footstep", -14.0 if not is_sprinting else -9.0, randf_range(0.85, 1.1))


func _unhandled_input(event: InputEvent) -> void:
	if not can_act():
		return
	for i in EquipmentManager.SLOT_COUNT:
		if event.is_action_pressed(StringName("slot_%d" % (i + 1))):
			equipment.select(i)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"use_equipment"):
		equipment.use_current()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"drop_item"):
		drop_current()
		get_viewport().set_input_as_handled()


func drop_current() -> void:
	var def := equipment.remove_selected()
	if def:
		drop_requested.emit(def, global_position + facing * 14.0)


# --- Perception ---------------------------------------------------------------

func has_handheld_light() -> bool:
	var item := equipment.get_current()
	return item != null and item.active and item is Flashlight


func has_line_of_sight(point: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, point, LOS_MASK)
	return space.intersect_ray(query).is_empty()


## How well the investigator can currently see a world point (0..1): the
## point must be inside the field of view, unobstructed and lit enough.
func perceive(point: Vector2) -> float:
	var to := point - global_position
	var dist := to.length()
	if dist < 14.0:
		return 1.0
	var angle := absf(facing.angle_to(to))
	if angle > VIEW_HALF_ANGLE:
		return 0.0
	var view_range := 130.0
	if house and house.is_point_lit(point):
		view_range = 520.0
	var item := equipment.get_current()
	if item and item.active:
		if item is Flashlight and angle < (item as Flashlight).half_angle:
			view_range = maxf(view_range, (item as Flashlight).beam_range)
		elif item is VideoCamera:
			view_range = maxf(view_range, 300.0)
	if dist > view_range:
		return 0.0
	if not has_line_of_sight(point):
		return 0.0
	var edge := 1.0 - smoothstep(VIEW_HALF_ANGLE * 0.7, VIEW_HALF_ANGLE, angle)
	return clampf((1.0 - (dist / view_range) * 0.5) * edge, 0.0, 1.0)


func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	var item := equipment.get_current()
	if item:
		item.set_active(false)
	died.emit()
