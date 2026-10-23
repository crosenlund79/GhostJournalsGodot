class_name Investigation
extends Node2D
## Root of an investigation. Builds the world from data, creates the systems,
## injects references and owns the game loop: start, death, exit, results,
## restart. Each system stays independent and talks through signals.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const GHOST_SCENE := preload("res://scenes/ghosts/ghost.tscn")
const FUSE_BOX_SCENE := preload("res://scenes/environment/fuse_box.tscn")
const WARDING_LAMP_SCENE := preload("res://scenes/environment/warding_lamp.tscn")
const WRITING_BOOK_SCENE := preload("res://scenes/environment/writing_book.tscn")
const EXIT_SCENE := preload("res://scenes/environment/exit_point.tscn")
const PICKUP_SCENE := preload("res://scenes/equipment/equipment_pickup.tscn")
const RITUAL_CIRCLE_SCENE := preload("res://scenes/environment/ritual_circle.tscn")

const TILE := InkStyle.TILE
const STARTING_EQUIPMENT: Array[StringName] = [&"flashlight"]
const RACK_EQUIPMENT: Array[StringName] = [&"uv_flashlight", &"emf_reader", &"spirit_box", &"video_camera", &"thermometer", &"ritual_kit"]

var database: GameDatabase
var balance: GameBalance
var ghost_definition: GhostDefinition

var manager: InvestigationManager
var electrical: ElectricalSystem
var temperature: TemperatureSystem
var lighting: LightingController
var safe_room: SafeRoomController
var hunt_director: HuntDirector

var world: Node2D
var house: House
var evidence_root: Node2D
var item_root: Node2D
var player: Player
var ghost: GhostController
var fuse_box: FuseBox
var warding_lamp: WardingLamp
var exit_point: ExitPoint
var books: Array[WritingBook] = []
var canvas_modulate: CanvasModulate

var hud: Hud
var journal: JournalUI
var pause_menu: PauseMenu
var death_screen: DeathScreen
var results_screen: ResultsScreen
var camera_overlay: CameraOverlay
var debug_overlay: DebugOverlay
var tutorial: TutorialDirector
var jump_scare: JumpScare
var _release_timer: float = -1.0

var _rng := RandomNumberGenerator.new()
var _death_timer: float = -1.0
var _debug_evidence_index: int = 0


func _ready() -> void:
	add_to_group(&"investigation")
	_rng.randomize()
	database = GameManager.database
	balance = database.balance
	ghost_definition = GameManager.pick_ghost_definition()
	GameManager.register_investigation(ghost_definition)
	_build_systems()
	_build_world()
	_build_ui()
	_connect_signals()
	AudioManager.start_loop(&"ambience", &"ambience_loop", -4.0)
	manager.add_field_note("Arrived at Hollow Lane. The house is dark; the power is off.")
	if GameManager.tutorial_mode:
		_setup_tutorial()
	else:
		hud.show_notice("Take what you need from the van. Find the fuse box.", &"info")


func _setup_tutorial() -> void:
	manager.is_tutorial = true
	ghost.harmless = true
	tutorial = TutorialDirector.new()
	tutorial.name = "TutorialDirector"
	add_child(tutorial)
	tutorial.setup(self)


func _exit_tree() -> void:
	AudioManager.stop_all_loops()


# --- Construction -------------------------------------------------------------

func _build_systems() -> void:
	manager = InvestigationManager.new()
	manager.name = "InvestigationManager"
	manager.setup(database, ghost_definition)
	add_child(manager)
	electrical = ElectricalSystem.new()
	electrical.name = "ElectricalSystem"
	add_child(electrical)
	temperature = TemperatureSystem.new()
	temperature.name = "TemperatureSystem"
	add_child(temperature)
	lighting = LightingController.new()
	lighting.name = "LightingController"
	add_child(lighting)
	safe_room = SafeRoomController.new()
	safe_room.name = "SafeRoomController"
	add_child(safe_room)
	hunt_director = HuntDirector.new()
	hunt_director.name = "HuntDirector"
	add_child(hunt_director)


func _build_world() -> void:
	canvas_modulate = CanvasModulate.new()
	canvas_modulate.name = "Darkness"
	add_child(canvas_modulate)
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	house = House.new()
	house.name = "House"
	world.add_child(house)
	var layout := OldHouseLayout.data()
	house.build(layout, electrical)

	evidence_root = Node2D.new()
	evidence_root.name = "Evidence"
	world.add_child(evidence_root)
	item_root = Node2D.new()
	item_root.name = "Items"
	item_root.add_to_group(&"item_root")
	world.add_child(item_root)

	# Fuse box hangs on the wall above its cell.
	fuse_box = FUSE_BOX_SCENE.instantiate()
	fuse_box.electrical = electrical
	var fb: Array = layout["fuse_box"]
	fuse_box.position = house.cell_to_world(Vector2i(fb[0], fb[1])) + Vector2(0, -TILE * 0.5 + 2)
	world.add_child(fuse_box)

	warding_lamp = WARDING_LAMP_SCENE.instantiate()
	var sh: Array = layout["safe_shrine"]
	warding_lamp.position = house.cell_to_world(Vector2i(sh[0], sh[1]))
	world.add_child(warding_lamp)
	safe_room.setup(house, electrical, warding_lamp)

	var yard_light := PointLight2D.new()
	yard_light.name = "VanFloodlight"
	yard_light.texture = house._make_light_texture()
	yard_light.texture_scale = 7.5 * TILE * 2.0 / 256.0
	yard_light.energy = 0.75
	yard_light.color = Color(0.85, 0.88, 1.0)
	yard_light.shadow_enabled = true
	yard_light.position = house.yard_light_position()
	world.add_child(yard_light)

	exit_point = EXIT_SCENE.instantiate()
	var ex: Array = layout["exit_point"]
	exit_point.position = Vector2(ex[0], ex[1]) * TILE
	world.add_child(exit_point)

	player = PLAYER_SCENE.instantiate()
	var sp: Array = layout["player_spawn"]
	player.position = Vector2(sp[0], sp[1]) * TILE
	world.add_child(player)

	ghost = GHOST_SCENE.instantiate()
	world.add_child(ghost)
	ghost.setup(ghost_definition, balance, house, player, electrical, manager, safe_room, evidence_root)

	player.configure(house, ghost, safe_room, manager, temperature, balance)
	player.facing = Vector2.UP
	temperature.setup(house, ghost, electrical)
	lighting.setup(house, canvas_modulate)
	hunt_director.setup(ghost, player, house, electrical, lighting, balance)

	for id in STARTING_EQUIPMENT:
		player.equipment.add_item(database.get_equipment(id))
	var slots: Array = layout["rack_slots"]
	for i in mini(slots.size(), RACK_EQUIPMENT.size()):
		var cell := Vector2i(slots[i][0], slots[i][1])
		spawn_pickup(database.get_equipment(RACK_EQUIPMENT[i]), house.cell_to_world(cell))

	_spawn_books(layout)


func _spawn_books(layout: Dictionary) -> void:
	var spots: Dictionary = layout.get("book_spots", {})
	var keys: Array = spots.keys()
	var chosen: Array[String] = []
	if spots.has(ghost.favorite_room.key):
		chosen.append(ghost.favorite_room.key)
	keys.shuffle()
	for k in keys:
		if chosen.size() >= 3:
			break
		if not chosen.has(k):
			chosen.append(k)
	for k in chosen:
		var options: Array = spots[k]
		var p: Array = options[_rng.randi() % options.size()]
		var book: WritingBook = WRITING_BOOK_SCENE.instantiate()
		book.room = house.rooms.get(k)
		book.position = house.cell_to_world(Vector2i(p[0], p[1]))
		item_root.add_child(book)
		books.append(book)


func _build_ui() -> void:
	hud = Hud.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(player, manager, safe_room, hunt_director)
	camera_overlay = CameraOverlay.new()
	camera_overlay.name = "CameraOverlay"
	add_child(camera_overlay)
	journal = JournalUI.new()
	journal.name = "Journal"
	add_child(journal)
	journal.setup(manager)
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	death_screen = DeathScreen.new()
	death_screen.name = "DeathScreen"
	add_child(death_screen)
	jump_scare = JumpScare.new()
	jump_scare.name = "JumpScare"
	add_child(jump_scare)
	results_screen = ResultsScreen.new()
	results_screen.name = "ResultsScreen"
	add_child(results_screen)
	if GameManager.debug_enabled:
		debug_overlay = DebugOverlay.new()
		debug_overlay.name = "DebugOverlay"
		add_child(debug_overlay)


func _connect_signals() -> void:
	player.drop_requested.connect(spawn_pickup)
	ghost.player_caught.connect(_on_player_caught)
	exit_point.exit_requested.connect(end_investigation.bind(true))
	journal.opened.connect(func() -> void: player.ui_blocked = true)
	journal.closed.connect(func() -> void: player.ui_blocked = false)
	pause_menu.resume_requested.connect(pause_menu.close)
	pause_menu.restart_requested.connect(GameManager.restart_current)
	pause_menu.menu_requested.connect(GameManager.go_to_main_menu)
	death_screen.continue_requested.connect(_show_results)
	death_screen.restart_requested.connect(GameManager.restart_current)
	results_screen.restart_requested.connect(GameManager.start_investigation)
	results_screen.menu_requested.connect(GameManager.go_to_main_menu)
	warding_lamp.examined.connect(func(text: String) -> void: manager.notify(text, &"info"))
	electrical.power_changed.connect(_on_power_changed)
	hunt_director.hunt_started.connect(func() -> void:
		manager.notify("The lights shudder. Something is hunting. Hide.", &"danger"))
	hunt_director.hunt_ended.connect(func() -> void:
		manager.notify("The house falls quiet again.", &"info"))
	safe_room.protection_changed.connect(func(on: bool) -> void:
		if player.house and player.house.get_room_at(player.global_position) == safe_room.room:
			manager.notify("The warding lamp flickers back to life." if on else "The warding lamp sputters out.", &"info"))


# --- Runtime hooks ------------------------------------------------------------

func spawn_pickup(def: EquipmentDefinition, world_position: Vector2) -> EquipmentPickup:
	var pickup: EquipmentPickup = PICKUP_SCENE.instantiate()
	pickup.definition = def
	pickup.position = world_position
	item_root.add_child(pickup)
	return pickup


## Called (via the "investigation" group) when a ritual kit is used.
func request_ritual_circle(kit: RitualKit, world_position: Vector2) -> void:
	var circle: RitualCircle = RITUAL_CIRCLE_SCENE.instantiate()
	circle.ghost = ghost
	circle.hunt_director = hunt_director
	circle.investigation = manager
	circle.position = world_position
	item_root.add_child(circle)
	var idx := player.equipment.slots.find(kit)
	if idx >= 0:
		player.equipment.remove_at(idx)
	manager.notify("You lay the salt circle and light the candles.", &"info")


## Called (via the "investigation" group) when the video camera toggles.
func on_camera_recording(on: bool) -> void:
	camera_overlay.set_recording(on)
	lighting.set_night_vision(on)


func _on_power_changed(on: bool, reason: String) -> void:
	if on:
		manager.notify("The house hums back to life.", &"info")
	elif reason == "ghost" or reason == "hunt":
		manager.notify("The power dies with a loud clunk.", &"danger")
		manager.add_field_note("The power was cut — not by me.")


func _on_player_caught() -> void:
	if player.is_dead or manager.finished:
		return
	if ghost.harmless:
		_harmless_catch()
		return
	journal.close()
	player.die()
	AudioManager.stop_loop(&"hunt")
	var scare := _play_catch_scare(2.0)
	# Show the death screen while the fog hides everything; the fog clears onto it.
	_death_timer = (JumpScare.RUSH_TIME + JumpScare.HOLD_TIME + JumpScare.FOG_TIME * 0.6) if scare else 1.8
	if not scare:
		var tween := create_tween()
		tween.tween_property(player.camera, "zoom", Vector2(3.4, 3.4), 0.5).set_trans(Tween.TRANS_EXPO)


## Scream + splash lunge from the ghost toward the investigator. Returns
## false when the ghost has no splash image (fallback: horror face + synth scream).
func _play_catch_scare(volume_db: float) -> bool:
	var def := ghost.definition
	if def.caught_sound:
		AudioManager.play_stream(def.caught_sound, volume_db)
	else:
		AudioManager.play(&"death", volume_db)
	if def.caught_sprite == null:
		return false
	var to_screen := get_viewport().get_canvas_transform() * player.global_position
	var from_screen := get_viewport().get_canvas_transform() * ghost.global_position
	jump_scare.play(def.caught_sprite, from_screen, to_screen)
	return true


## Tutorial catch: the full scare, then the ghost lets go and the hunt ends.
func _harmless_catch() -> void:
	var scare := _play_catch_scare(-3.0)
	manager.notify("It caught you. In a real investigation, you would be dead.", &"danger")
	manager.add_field_note("The entity caught me during a hunt. (Training: no harm done.)")
	_release_timer = JumpScare.TOTAL_TIME if scare else 1.4


func _process(delta: float) -> void:
	if _release_timer >= 0.0:
		_release_timer -= delta
		if _release_timer < 0.0:
			ghost.release_player()
			hunt_director.end_hunt()
	if _death_timer >= 0.0:
		_death_timer -= delta
		if not jump_scare.playing:
			player.camera.offset = Vector2(randf_range(-3, 3), randf_range(-3, 3)) * clampf(_death_timer, 0.0, 1.0)
		if _death_timer < 0.0:
			player.camera.offset = Vector2.ZERO
			hunt_director.shutdown()
			manager.finish(false)
			death_screen.show_screen(jump_scare.playing)
	if debug_overlay and debug_overlay.visible:
		debug_overlay.set_text(_debug_text())


func end_investigation(survived: bool) -> void:
	if manager.finished:
		return
	journal.close()
	hunt_director.shutdown()
	manager.finish(survived)
	_show_results()


func _show_results() -> void:
	AudioManager.stop_all_loops()
	death_screen.visible = false
	results_screen.show_results(manager.results)
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		if journal.is_open:
			journal.close()
		elif not manager.finished and not player.is_dead:
			pause_menu.open()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"journal") and not manager.finished and not player.is_dead:
		journal.toggle()
		get_viewport().set_input_as_handled()
		return
	if GameManager.debug_enabled:
		_handle_debug_input(event)


# --- Debug --------------------------------------------------------------------

func _handle_debug_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle"):
		debug_overlay.visible = not debug_overlay.visible
		DebugFlags.show_world_debug = debug_overlay.visible
	elif event.is_action_pressed(&"debug_cycle_evidence"):
		_debug_evidence_index = (_debug_evidence_index + 1) % database.evidence.size()
	elif event.is_action_pressed(&"debug_manifest"):
		ghost.start_manifestation()
	elif event.is_action_pressed(&"debug_hunt"):
		if hunt_director.is_hunting:
			hunt_director.end_hunt()
		else:
			hunt_director.start_hunt()
	elif event.is_action_pressed(&"debug_power"):
		electrical.toggle("debug")
	elif event.is_action_pressed(&"debug_evidence"):
		debug_generate_evidence(database.evidence[_debug_evidence_index].id)
	elif event.is_action_pressed(&"debug_reveal"):
		ghost.debug_reveal = not ghost.debug_reveal
	elif event.is_action_pressed(&"debug_reset"):
		GameManager.start_investigation()


## Creates a detectable instance of the given evidence near the player. The
## player still has to detect it with the right tool (except Spirit Box).
func debug_generate_evidence(evidence_id: StringName) -> void:
	var front := player.global_position + player.facing * 28.0
	var room := house.get_room_at(player.global_position)
	match evidence_id:
		&"emf_5":
			EmfSource.spawn(evidence_root, front, 5, 20.0)
		&"uv_prints":
			ghost.spawn_uv_print(front)
		&"spirit_box":
			manager.observe(&"spirit_box", room.display_name if room else "", "debug response")
		&"orbs":
			var orb := GhostOrb.new()
			orb.house = house
			orb.room = room if room else ghost.favorite_room
			evidence_root.add_child(orb)
			orb.global_position = front
		&"freezing":
			if room:
				room.temperature = -6.0
		&"writing":
			var book: WritingBook = WRITING_BOOK_SCENE.instantiate()
			book.room = room
			book.position = front
			item_root.add_child(book)
			book.write()
	manager.notify("[debug] generated %s" % evidence_id, &"info")


func _debug_text() -> String:
	var room := ghost.current_room.display_name if ghost.current_room else "?"
	var lines := PackedStringArray([
		"DEBUG  (F3 hide)",
		"Ghost: %s" % ghost_definition.display_name,
		"State: %s" % ghost.state_name(),
		"Position: (%d, %d)  cell %s" % [int(ghost.global_position.x), int(ghost.global_position.y), house.world_to_cell(ghost.global_position)],
		"Room: %s   favourite: %s" % [room, ghost.favorite_room.display_name],
		"Perceived: %.2f" % ghost.perceived_amount,
		"Sanity: %.1f  (%+.2f/s)" % [player.sanity.value, player.sanity.current_rate],
		"Power: %s   Safe room: %s" % ["on" if electrical.is_powered() else "off", "warded" if safe_room.protected else "open"],
		"Hunt: %s  chance %.2f  cooldown %.0f" % ["YES %.0fs" % hunt_director.hunt_time_left if hunt_director.is_hunting else "no", hunt_director.hunt_chance(), maxf(0.0, hunt_director.cooldown)],
		"Temp here: %.1f °C" % temperature.get_temperature_at(player.global_position),
		"Observed: %s" % ", ".join(PackedStringArray(manager.observed.keys().map(func(k: StringName) -> String: return String(k)))),
		"",
		"F4 evidence: %s" % database.evidence[_debug_evidence_index].display_name,
		"F5 manifest  F6 hunt  F7 power  F8 make evidence",
		"F9 reveal ghost  F10 reset",
	])
	return "\n".join(lines)
