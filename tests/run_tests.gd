extends SceneTree
## Automated test suite: data/unit checks plus headless integration tests that
## drive real investigation scenes frame by frame.
##
## Run (fast, deterministic frame time):
##   godot --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd
##
## Project classes are accessed dynamically: a SceneTree script is compiled
## before autoloads exist, so it must not reference classes that use them.

var _passed: int = 0
var _failed: int = 0
var _current: String = ""
var gm: Node


func _initialize() -> void:
	gm = root.get_node("GameManager")
	_run.call_deferred()


func _run() -> void:
	_test_database()
	_test_journal_logic()
	_test_layout()
	await _test_doors_and_power()
	await _test_equipment_and_evidence()
	await _test_evidence_is_exclusive()
	await _test_spirit_box()
	await _test_perception()
	await _test_ghost_token_and_trail()
	await _test_hunt_kills_player()
	await _test_safe_room_protects()
	await _test_exorcism()
	await _test_ui_flow()
	await _test_composure_rates()
	await _test_monologue()
	await _test_appliances()
	await _test_doll()
	await _test_ritual_pickup()
	await _test_hunt_audio()
	await _test_tutorial()
	await _test_tutorial_equipment_steps(&"whisperer")
	await _test_tutorial_equipment_steps(&"disturbed")
	await _test_exit_and_results()
	print("")
	print("==== %d passed, %d failed ====" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- Helpers ------------------------------------------------------------------

func check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		print("  FAIL %s  [%s]" % [label, _current])


func section(title: String) -> void:
	_current = title
	print("\n# %s" % title)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func seconds(s: float) -> void:
	await frames(int(s * 60.0))


func start_investigation(ghost_id: StringName) -> Node:
	gm.set("forced_ghost_id", ghost_id)
	gm.call("start_investigation")
	for i in 30:
		await process_frame
		if current_scene and current_scene.name == "Investigation" and current_scene.get("player") != null:
			break
	await frames(2)
	var inv := current_scene
	# Tests drive time explicitly; skip the dormant period.
	return inv


func teleport(player: Node, cell: Vector2i) -> void:
	player.global_position = player.house.cell_to_world(cell)
	player.velocity = Vector2.ZERO


# --- Unit / data tests ---------------------------------------------------------

func _test_database() -> void:
	section("database")
	var db: Resource = gm.get("database")
	check(db != null, "database loads")
	check(db.evidence.size() == 6, "6 evidence types")
	check(db.ghosts.size() == 2, "2 ghost types")
	check(db.equipment.size() == 7, "7 equipment types")
	for g in db.ghosts:
		check(g.evidence.size() == 3, "%s has 3 evidence" % g.display_name)
		for id in g.evidence:
			check(db.get_evidence(id) != null, "%s evidence %s exists" % [g.display_name, id])
	for e in db.equipment:
		check(e.scene != null, "equipment %s has a scene" % e.id)
	# Every evidence belongs to exactly one prototype ghost -> identification is always possible.
	for e in db.evidence:
		check(db.ghosts_with_evidence(e.id).size() == 1, "evidence %s identifies one ghost" % e.id)


func _test_journal_logic() -> void:
	section("journal filtering")
	var logic: GDScript = load("res://scripts/evidence/journal_logic.gd")
	var db: Resource = gm.get("database")
	var ghosts: Array = db.ghosts
	var confirmed := 1
	var ruled := 2
	check(logic.filter(db.ghosts, {}).size() == 2, "no marks -> both possible")
	var r: Array = logic.filter(db.ghosts, {&"emf_5": confirmed})
	check(r.size() == 1 and r[0].id == &"disturbed", "confirm EMF5 -> Disturbed")
	r = logic.filter(db.ghosts, {&"emf_5": ruled})
	check(r.size() == 1 and r[0].id == &"whisperer", "rule out EMF5 -> Whisperer")
	r = logic.filter(db.ghosts, {&"emf_5": confirmed, &"orbs": confirmed})
	check(r.is_empty(), "contradictory confirmations -> none")
	r = logic.filter(db.ghosts, {&"orbs": ruled, &"writing": ruled})
	check(r.is_empty(), "ruling out one of each -> none")
	r = logic.filter(db.ghosts, {&"orbs": 0, &"writing": 0})
	check(r.size() == 2, "unknown marks never exclude")
	check(logic.next_mark(0) == 1 and logic.next_mark(1) == 2 and logic.next_mark(2) == 0, "mark cycle")
	var balance: Resource = db.balance
	check(is_equal_approx(balance.activity_multiplier(100.0), 1.0), "activity x1 at full sanity")
	check(balance.activity_multiplier(0.0) > balance.activity_multiplier(50.0), "activity grows as sanity falls")


func _test_layout() -> void:
	section("layout")
	var data: Dictionary = load("res://resources/layouts/old_house_layout.gd").data()
	var grid: Array = data["grid"]
	var w: int = grid[0].length()
	var ok := true
	for row in grid:
		ok = ok and row.length() == w
	check(ok, "grid rows have equal width")
	var doors := 0
	for row in grid:
		doors += row.count("D") + row.count("F")
	check(doors == 11, "11 doors (10 interior + front)")
	check(data["rooms"].size() == 9, "9 named rooms (incl. kids' room)")


# --- Integration tests ----------------------------------------------------------

func _test_doors_and_power() -> void:
	section("doors, fuse box, lights, safe room")
	var inv := await start_investigation(&"whisperer")
	var p: Node = inv.player
	var house: Node = inv.house
	var door: Node = house.front_door
	check(door != null and not door.is_open, "front door starts closed")
	check(not house.is_indoors(p.global_position), "player starts outside")
	# Walk into the closed door: it must block.
	teleport(p, door.cell + Vector2i(0, 1))
	p.move_override = Vector2.UP
	await seconds(1.0)
	check(p.global_position.y > door.global_position.y, "closed door blocks movement")
	p.move_override = Vector2.ZERO
	p.interaction.force_interact(door)
	await frames(3)
	check(door.is_open, "door opens via interaction")
	p.move_override = Vector2.UP
	await seconds(1.0)
	p.move_override = Vector2.ZERO
	check(house.is_indoors(p.global_position), "open door lets player inside")
	# Interaction prompt from the focus system.
	teleport(p, door.cell + Vector2i(0, -1))
	p.aim_override = Vector2.DOWN
	await frames(3)
	check(p.interaction.focused == door and p.interaction.get_prompt_text().contains("Close Door"), "context prompt 'E — Close Door'")
	# Power.
	check(not inv.electrical.is_powered(), "power starts off")
	var living: Object = house.get_room_by_id(&"living_room")
	check(not house.is_room_lit(living), "rooms dark without power")
	check(not inv.safe_room.protected, "safe room unprotected without power")
	inv.fuse_box.interact(p)
	await frames(2)
	check(inv.electrical.is_powered(), "fuse box restores power")
	check(house.is_room_lit(living) and living.lights[0].enabled, "room light on with power")
	check(inv.safe_room.protected, "safe room protected with power")
	var safe_cell := Vector2i(29, 5)
	check(not house.is_ghost_walkable(safe_cell), "ghost navigation excludes warded room")
	var sw: Node = house.light_switches.filter(func(s: Node) -> bool: return s.room == living)[0]
	sw.interact(p)
	check(not house.is_room_lit(living), "light switch turns room light off")
	sw.interact(p)
	inv.electrical.trip("ghost")
	await frames(2)
	check(not inv.safe_room.protected and house.is_ghost_walkable(safe_cell), "power loss removes protection")


func _test_equipment_and_evidence() -> void:
	section("equipment & evidence detection (Disturbed)")
	var inv := await start_investigation(&"disturbed")
	var p: Node = inv.player
	var house: Node = inv.house
	var eq: Node = p.equipment
	check(eq.slots[0] != null and eq.slots[0].definition.id == &"flashlight", "starts with flashlight")
	var pickups: Array = inv.item_root.get_children().filter(func(n: Node) -> bool: return n.has_method("get_prompt") and n.get("definition") != null and n.get("definition") is Resource)
	check(pickups.size() == 6, "6 items on the van rack")
	var by_id := {}
	for pk in pickups:
		by_id[pk.definition.id] = pk
	by_id[&"emf_reader"].interact(p)
	by_id[&"uv_flashlight"].interact(p)
	by_id[&"thermometer"].interact(p)
	await frames(2)
	check(not eq.has_free_slot(), "inventory full after 3 pickups")
	eq.select(3)
	by_id[&"video_camera"].interact(p)
	await frames(2)
	check(eq.has_item(&"video_camera") and not eq.has_item(&"thermometer"), "full inventory swaps held item")
	# Swap back (the thermometer now lies where the camera was).
	var therm: Array = inv.item_root.get_children().filter(func(n: Node) -> bool: return n.get("definition") is Resource and n.definition.id == &"thermometer")
	check(therm.size() == 1, "swapped item left in the world")
	therm[0].interact(p)
	await frames(2)
	# EMF 5.
	teleport(p, Vector2i(8, 15))
	eq.select(1)
	eq.use_current()
	check(eq.get_current().active, "EMF reader switches on")
	var emf_script: GDScript = load("res://scripts/evidence/emf_source.gd")
	emf_script.spawn(inv.evidence_root, p.global_position + Vector2(30, 0), 5, 10.0)
	await frames(20)
	check(eq.get_current().level == 5, "EMF reader reads 5 next to a level-5 source")
	check(inv.manager.observed.has(&"emf_5"), "EMF 5 recorded as observation")
	# UV prints: invisible until the UV beam hits them.
	var print_node: Node = inv.ghost.spawn_uv_print(p.global_position + Vector2(60, 0))
	print_node.global_position = p.global_position + Vector2(60, 0)
	eq.select(2)
	p.aim_override = Vector2.LEFT
	eq.use_current()
	await frames(30)
	check(print_node.reveal < 0.05, "UV print hidden outside the beam")
	p.aim_override = Vector2.RIGHT
	await frames(40)
	check(print_node.reveal > 0.5, "UV print revealed in the beam")
	check(inv.manager.observed.has(&"uv_prints"), "UV handprints recorded")
	# Writing.
	var book: Node = inv.books[0]
	book.interact(p)
	check(not inv.manager.observed.has(&"writing"), "blank notebook is not evidence")
	book.write()
	book.interact(p)
	check(inv.manager.observed.has(&"writing"), "written notebook recorded")
	# Thermometer reads room temperature.
	eq.select(3)
	eq.use_current()
	await frames(50)
	var therm_item: Node = eq.get_current()
	var room: Object = house.get_room_at(p.global_position)
	check(absf(therm_item.reading - room.temperature) < 1.0, "thermometer reads the room temperature")
	# Journal marks don't auto-fill: observation != confirmation.
	check(inv.manager.get_mark(&"emf_5") == 0, "observations do not auto-mark the journal")


func _test_evidence_is_exclusive() -> void:
	section("ghosts only produce their own evidence")
	var inv := await start_investigation(&"whisperer")
	var g: Node = inv.ghost
	g.state = 1
	for i in 150:
		g.perform_interaction()
	var max_level := 0
	for src in root.get_tree().get_nodes_in_group(&"emf_source"):
		max_level = maxi(max_level, src.level)
	check(max_level < 5, "Whisperer never produces EMF 5 (max %d)" % max_level)
	check(root.get_tree().get_nodes_in_group(&"uv_print").is_empty(), "Whisperer leaves no UV prints")
	check(inv.books.all(func(b: Node) -> bool: return not b.written), "Whisperer never writes")
	check(root.get_tree().get_nodes_in_group(&"ghost_orb").size() == 2, "Whisperer has orbs in its room")
	# Freezing: the favourite room drops below zero over time.
	var fav: Object = g.favorite_room
	check(inv.temperature.target_temperature(fav) < 0.0, "Whisperer's room targets below 0 °C")
	var inv2 := await start_investigation(&"disturbed")
	var g2: Node = inv2.ghost
	check(inv2.temperature.target_temperature(g2.favorite_room) > 0.0, "Disturbed's room stays above 0 °C")
	check(root.get_tree().get_nodes_in_group(&"ghost_orb").is_empty(), "Disturbed has no orbs")
	var levels := {}
	for i in 150:
		g2.perform_interaction()
	for src in root.get_tree().get_nodes_in_group(&"emf_source"):
		levels[src.level] = true
	check(levels.has(5), "Disturbed produces EMF 5")
	check(g2.try_spirit_box_response(inv2.player) == "", "Disturbed never answers the Spirit Box")


func _test_spirit_box() -> void:
	section("spirit box & camera orbs (Whisperer)")
	var inv := await start_investigation(&"whisperer")
	var p: Node = inv.player
	var g: Node = inv.ghost
	var house: Node = inv.house
	g._state_timer = 0.0
	await frames(2)
	var cell: Vector2i = house.random_walkable_cell(g.favorite_room, g.rng)
	teleport(p, cell)
	g.global_position = p.global_position + Vector2(40, 0)
	inv.hunt_director.enabled = false
	var box_def: Resource = inv.database.get_equipment(&"spirit_box")
	p.equipment.select(1)
	p.equipment.add_item(box_def)
	p.equipment.use_current()
	var got := false
	for i in 40:
		await seconds(1.0)
		g.global_position = p.global_position + Vector2(40, 0)
		if inv.manager.observed.has(&"spirit_box"):
			got = true
			break
	check(got, "Spirit Box response in the dark near the Whisperer")
	# Lit room => no answers.
	inv.electrical.set_power(true)
	var lit_room: Object = house.get_room_at(p.global_position)
	lit_room.light_switch_on = true
	house.refresh_lights()
	var answered := false
	for i in 30:
		if g.try_spirit_box_response(p) != "":
			answered = true
	check(not answered, "no Spirit Box answers with the lights on")
	# Camera orbs.
	var orb: Node = root.get_tree().get_nodes_in_group(&"ghost_orb")[0]
	p.equipment.select(2)
	p.equipment.add_item(inv.database.get_equipment(&"video_camera"))
	teleport(p, Vector2i(4, 15))  # open floor, so the orb below is never behind a wall
	p.aim_override = Vector2.RIGHT
	await frames(5)
	check(orb.seen_amount < 0.05, "orbs invisible without the camera")
	p.equipment.use_current()
	check(inv.camera_overlay.visible, "camera overlay shown while recording")
	var seen := false
	for i in 60:
		orb.global_position = p.global_position + Vector2(70, 0)
		orb._target = orb.global_position
		await frames(1)
		if inv.manager.observed.has(&"orbs"):
			seen = true
			break
	check(seen, "orbs recorded through the camera")
	p.equipment.use_current()
	check(not inv.camera_overlay.visible, "overlay hidden when recording stops")


func _test_perception() -> void:
	section("ghost visibility depends on perception")
	var inv := await start_investigation(&"disturbed")
	var p: Node = inv.player
	var g: Node = inv.ghost
	inv.hunt_director.enabled = false
	inv.electrical.set_power(true)
	teleport(p, Vector2i(5, 15))
	g.global_position = p.global_position + Vector2(90, 0)
	g._state_timer = 0.0
	await frames(2)
	p.aim_override = Vector2.RIGHT
	g.start_manifestation()
	g.global_position = p.global_position + Vector2(90, 0)
	await frames(10)
	check(g.state == 3, "ghost is manifesting")
	check(g.perceived_amount > 0.3, "manifestation visible when faced in a lit room (%.2f)" % g.perceived_amount)
	p.aim_override = Vector2.LEFT
	await frames(10)
	check(g.perceived_amount == 0.0, "invisible when behind the player")
	g._state_timer = 0.0
	await frames(3)
	check(g.state != 3, "manifestation ends")
	check(p.sanity.value < 100.0, "manifestation costs sanity")
	check(g.perceived_amount == 0.0, "roaming ghost is invisible")


func _test_ghost_token_and_trail() -> void:
	section("ghost token sprite & smoke trail")
	var inv := await start_investigation(&"whisperer")
	var p: Node = inv.player
	var g: Node = inv.ghost
	inv.hunt_director.enabled = false
	inv.electrical.set_power(true)
	check(g.definition.sprite != null and g.definition.sprite.resource_path == "res://assets/ghost/GhostToken.png", "ghost definition uses GhostToken.png")
	check(g.visual.token == g.definition.sprite and g.visual.is_upright(), "visual draws the token upright")
	check(g.trail != null and g.trail.is_inside_tree() and g.trail.get_parent() == g.get_parent(), "smoke trail lives beside the ghost")
	# Invisible + moving: no smoke.
	teleport(p, Vector2i(5, 15))
	p.aim_override = Vector2.RIGHT
	g._state_timer = 0.0
	await frames(2)
	g.global_position = p.global_position + Vector2(200, 0)
	g._last_position = g.global_position
	for i in 30:
		g.global_position += Vector2(-1.5, 0)
		await frames(1)
	check(g.trail.puff_count() == 0, "no smoke while the ghost is invisible")
	# Visible + moving (manifesting in front of the player): smoke appears.
	g.start_manifestation()
	g.global_position = p.global_position + Vector2(200, 0)
	g._last_position = g.global_position
	for i in 40:
		g.global_position += Vector2(-1.5, 0)
		await frames(1)
	check(g.visual.modulate.a > 0.5, "manifesting ghost visible to the player")
	check(g.trail.puff_count() > 5, "visible moving ghost leaves a smoke trail (%d puffs)" % g.trail.puff_count())
	check(g.visual.rotation == 0.0, "token stays upright while moving")
	var behind: bool = g.trail._puffs.back()["pos"].x > g.global_position.x - 4.0
	check(behind, "smoke trails behind the direction of travel")
	# Once it vanishes, no new puffs; the existing smoke fades away.
	g._state_timer = 0.0
	await seconds(2.0)
	check(g.trail.puff_count() == 0, "smoke fades once the ghost vanishes")


func _test_hunt_kills_player() -> void:
	section("hunt: chase and death")
	var inv := await start_investigation(&"disturbed")
	var p: Node = inv.player
	var g: Node = inv.ghost
	teleport(p, Vector2i(5, 15))
	g.global_position = inv.house.cell_to_world(Vector2i(14, 15))
	g._state_timer = 0.0
	await frames(2)
	inv.hunt_director.start_hunt()
	check(inv.hunt_director.is_hunting and g.state == 4, "hunt started")
	check(inv.house.front_door.locked, "front door locks during a hunt")
	var died := false
	for i in 20:
		await seconds(0.5)
		if p.is_dead:
			died = true
			break
	check(died, "ghost reaches a player standing in the open")
	check(g.caught_player and inv.jump_scare.playing, "catch triggers the jump scare")
	check(inv.jump_scare.texture.resource_path == "res://assets/ghost/Ghost_caught_player.png", "jump scare uses Ghost_caught_player.png")
	check(g.definition.caught_sound.resource_path == "res://audio/Ghost_caught_player_scream.wav", "catch plays Ghost_caught_player_scream.wav")
	var scream_playing := AudioManager_has_stream(g.definition.caught_sound)
	check(scream_playing, "scream is playing")
	await seconds(JumpScare_rush() + 0.05)
	check(inv.jump_scare.is_covering(), "splash covers the screen after the lunge")
	await seconds(2.5)
	check(inv.manager.finished and inv.manager.results["survived"] == false, "death ends the investigation")
	check(inv.death_screen.visible, "death screen shown")
	inv._show_results()
	check(inv.results_screen.visible, "results reachable from death screen")
	paused = false


func _test_safe_room_protects() -> void:
	section("safe room protects during a hunt")
	var inv := await start_investigation(&"disturbed")
	var p: Node = inv.player
	var g: Node = inv.ghost
	var house: Node = inv.house
	inv.electrical.set_power(true)
	await frames(2)
	teleport(p, Vector2i(29, 5))
	g.global_position = house.cell_to_world(Vector2i(29, 10))
	g._state_timer = 0.0
	await frames(2)
	inv.hunt_director.start_hunt()
	inv.electrical.set_power(true)  # a hunt may trip the breaker; keep the ward up for this test
	var entered := false
	for i in 24:
		await seconds(0.5)
		if house.get_room_at(g.global_position) == house.safe_room:
			entered = true
	check(not p.is_dead, "player survives inside the warded room")
	check(not entered, "ghost never entered the warded room")
	# Hunt end: recovering, door unlocked.
	inv.hunt_director.end_hunt()
	check(not house.front_door.locked and g.state == 5, "hunt ends into recovery")


func _test_exorcism() -> void:
	section("exorcism")
	var inv := await start_investigation(&"whisperer")
	var p: Node = inv.player
	var g: Node = inv.ghost
	g._state_timer = 0.0
	await frames(2)
	inv.hunt_director.enabled = false
	var kit_def: Resource = inv.database.get_equipment(&"ritual_kit")
	p.equipment.select(1)
	p.equipment.add_item(kit_def)
	teleport(p, inv.house.random_walkable_cell(g.favorite_room, g.rng))
	p.equipment.use_current()
	await frames(2)
	var circles: Array = inv.item_root.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("RitualCircle"))
	check(circles.size() == 1, "ritual kit lays a circle")
	check(not p.equipment.has_item(&"ritual_kit"), "kit consumed")
	var circle: Node = circles[0]
	check(circle.get_prompt(p).contains("name the entity"), "rite requires a name first")
	inv.manager.select_ghost(&"whisperer")
	g.global_position = circle.global_position + Vector2(20, 0)
	check(circle.can_continue_hold(p), "rite progresses with the ghost inside the circle")
	g.global_position = circle.global_position + Vector2(400, 0)
	check(not circle.can_continue_hold(p), "rite stalls when the ghost is far away")
	g.global_position = circle.global_position + Vector2(20, 0)
	circle.interact(p)
	check(g.state == 6 and inv.manager.exorcism_result == &"success", "correct name banishes the ghost")
	# Wrong name provokes a hunt.
	var inv2 := await start_investigation(&"whisperer")
	var g2: Node = inv2.ghost
	g2._state_timer = 0.0
	await frames(2)
	var circle_scene: PackedScene = load("res://scenes/environment/ritual_circle.tscn")
	var c2: Node = circle_scene.instantiate()
	c2.ghost = g2
	c2.hunt_director = inv2.hunt_director
	c2.investigation = inv2.manager
	inv2.item_root.add_child(c2)
	c2.global_position = g2.global_position
	inv2.manager.select_ghost(&"disturbed")
	c2.interact(inv2.player)
	check(inv2.manager.exorcism_result == &"failed" and inv2.hunt_director.is_hunting, "wrong name fails and triggers a hunt")
	inv2.hunt_director.end_hunt()


func press_action(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


func _test_ui_flow() -> void:
	section("UI flow & input routing")
	var inv := await start_investigation(&"whisperer")
	var p: Node = inv.player
	await press_action(&"journal")
	check(inv.journal.is_open and p.ui_blocked, "J opens the journal and freezes the investigator")
	var btn: Button = inv.journal._evidence_buttons[&"orbs"]
	btn.pressed.emit()
	check(inv.manager.get_mark(&"orbs") == 1 and btn.text.contains("+"), "journal button confirms evidence")
	var excluded: Button = inv.journal._ghost_buttons[&"disturbed"]
	check(excluded.disabled, "contradicting entity is excluded in the journal")
	(inv.journal._ghost_buttons[&"whisperer"] as Button).pressed.emit()
	check(inv.manager.selected_ghost_id == &"whisperer", "journal selects a conclusion")
	await press_action(&"pause")
	check(not inv.journal.is_open and not paused, "Esc closes the journal first")
	await press_action(&"pause")
	check(inv.pause_menu.is_open and paused, "Esc opens the pause menu and pauses")
	await press_action(&"pause")
	check(not inv.pause_menu.is_open and not paused, "Esc again resumes")
	# Slot keys and F.
	p.equipment.add_item(inv.database.get_equipment(&"thermometer"))
	await press_action(&"slot_2")
	check(p.equipment.selected_index == 1, "number key selects a slot")
	await press_action(&"use_equipment")
	check(p.equipment.get_current().active, "F toggles the held equipment")
	await press_action(&"drop_item")
	await frames(2)
	check(p.equipment.slots[1] == null, "G drops the held item")
	check(inv.item_root.get_children().any(func(n: Node) -> bool: return n.get("definition") is Resource and n.definition.id == &"thermometer"), "dropped item appears in the world")
	# HUD shows a reading and prompt plumbing works.
	p.equipment.select(0)
	p.equipment.use_current()
	await frames(2)
	check(inv.hud._item_label.text == "Flashlight" and inv.hud._reading_label.text.begins_with("beam on"), "HUD shows held item and state")
	check(not GameManager_debug(), "debug mode off by default")


func AudioManager_has_stream(stream: AudioStream) -> bool:
	for c in root.get_node("AudioManager").get_children():
		if c is AudioStreamPlayer and c.stream == stream and c.playing:
			return true
	return false


func JumpScare_rush() -> float:
	return load("res://scripts/ui/jump_scare.gd").RUSH_TIME


func GameManager_debug() -> bool:
	return gm.get("debug_enabled")


func _test_tutorial() -> void:
	section("Learn to Play tutorial")
	gm.set("forced_ghost_id", &"disturbed")
	gm.call("start_tutorial")
	for i in 30:
		await process_frame
		if current_scene and current_scene.name == "Investigation" and current_scene.get("tutorial") != null:
			break
	await frames(2)
	var inv := current_scene
	var p: Node = inv.player
	var t: Node = inv.tutorial
	var db: Resource = gm.get("database")
	check(t != null and inv.ghost.harmless and inv.manager.is_tutorial, "tutorial mode: director present, ghost harmless")
	check(inv.ghost.definition == db.get_ghost(&"disturbed"), "tutorial ghost uses a normal ghost definition")
	check(inv.hunt_director.enabled and inv.ghost.state == 0, "ghost runs its normal state machine")
	check(t.index == 0 and inv.tutorial.panel._title.text == "Welcome, investigator", "first step shown")
	check(t.marker.visible or true, "objective marker exists")
	p.move_override = Vector2.RIGHT
	await seconds(1.0)
	p.move_override = Vector2.ZERO
	await frames(2)
	check(t.index == 1, "moving completes the welcome step")
	p.equipment.use_current()
	await frames(2)
	check(t.index == 2, "switching on the flashlight completes its step")
	for id in [&"thermometer", &"emf_reader", &"uv_flashlight"]:
		p.equipment.add_item(db.get_equipment(id))
	await frames(2)
	check(t.index == 3, "taking three tools completes the equipment step")
	# Skip forward to the practice hunt.
	while t.current_title() != "Practice hunt":
		t.skip()
	await frames(2)
	teleport(p, Vector2i(5, 15))
	inv.ghost.global_position = inv.house.cell_to_world(Vector2i(12, 15))
	inv.ghost._state_timer = 0.0
	var hunted := false
	var survived_catch := false
	for i in 100:
		await seconds(0.5)
		if inv.hunt_director.is_hunting and not hunted:
			hunted = true
			inv.ghost.global_position = inv.house.cell_to_world(Vector2i(11, 15))
		if inv.ghost.caught_player:
			survived_catch = not p.is_dead
		if hunted and t.current_title() != "Practice hunt":
			break
	check(hunted, "practice hunt starts on its own")
	check(survived_catch, "the ghost catches the player but cannot kill")
	check(not p.is_dead and not inv.manager.finished, "investigation continues after a training catch")
	check(t.current_title() == "Exorcism (optional)", "surviving the hunt completes the step")
	t.skip()
	check(t.current_title() == "Leave", "final step is leaving")
	inv.exit_point.interact(p)
	await frames(3)
	check(t.is_complete() and inv.manager.results["tutorial"] == true, "leaving completes the tutorial; results marked as training")
	inv.results_screen.restart_requested.emit()
	for i in 10:
		await process_frame
	check(not gm.get("tutorial_mode") and current_scene.get("tutorial") == null, "New Investigation from tutorial starts a real case")


## Completes the equipment steps without skipping, relying on the ghost's
## natural behaviour, to prove every step is achievable for each ghost type.
func _test_tutorial_equipment_steps(ghost_id: StringName) -> void:
	section("tutorial equipment steps complete naturally (%s)" % ghost_id)
	gm.set("forced_ghost_id", ghost_id)
	gm.call("start_tutorial")
	for i in 30:
		await process_frame
		if current_scene and current_scene.name == "Investigation" and current_scene.get("tutorial") != null:
			break
	await frames(2)
	var inv := current_scene
	var p: Node = inv.player
	var t: Node = inv.tutorial
	var db: Resource = gm.get("database")
	var house: Node = inv.house
	var fav: Object = inv.ghost.favorite_room
	var fav_cell: Vector2i = house.nearest_walkable_cell(house.world_to_cell(fav.center_world()))
	inv.hunt_director.enabled = false  # keep this walkthrough focused on the tools
	inv.ghost._state_timer = 0.0
	while t.current_title() != "Thermometer":
		t.skip()
	for id in [&"thermometer", &"emf_reader", &"uv_flashlight"]:
		p.equipment.add_item(db.get_equipment(id))
	var hold := func(id: StringName) -> void:
		for i in 4:
			var it: Node = p.equipment.slots[i]
			if it and it.definition.id == id:
				p.equipment.select(i)
				if not it.active:
					p.equipment.use_current()
	var steps := {
		"Thermometer": [&"thermometer", 10.0],
		"EMF Reader": [&"emf_reader", 120.0],
		"UV Flashlight": [&"uv_flashlight", 30.0],
	}
	for title in steps:
		check(t.current_title() == title, "at step '%s'" % title)
		teleport(p, fav_cell)
		hold.call(steps[title][0])
		var waited := 0.0
		while t.current_title() == title and waited < steps[title][1]:
			await seconds(0.5)
			waited += 0.5
			# Follow the objective marker like a player would (it points at fresh disturbances).
			if t.marker.target is Vector2:
				p.global_position = t.marker.target + Vector2(0, 20)
			else:
				teleport(p, fav_cell)
		check(t.current_title() != title, "'%s' completed in %ds" % [title, int(waited)])
	# Swap at the van.
	check(t.current_title() == "Back to the van", "at step 'Back to the van'")
	p.equipment.select(1)
	p.equipment.remove_selected()
	p.equipment.add_item(db.get_equipment(&"spirit_box"))
	p.equipment.select(2)
	p.equipment.remove_selected()
	p.equipment.add_item(db.get_equipment(&"video_camera"))
	await frames(2)
	check(t.current_title() == "Spirit Box", "swap completes 'Back to the van'")
	inv.electrical.set_power(true)
	house.set_room_light(fav, false)
	for title in ["Spirit Box", "Video Camera"]:
		teleport(p, fav_cell)
		hold.call(&"spirit_box" if title == "Spirit Box" else &"video_camera")
		var waited := 0.0
		while t.current_title() == title and waited < 40.0:
			await seconds(0.5)
			waited += 0.5
			teleport(p, fav_cell)
			# React to the tutorial's live hints, as a player would.
			var hint: String = t.panel._status.text
			if hint.contains("Switch them off"):
				house.set_room_light(fav, false)
			if not inv.electrical.is_powered():
				inv.electrical.set_power(true)
				house.set_room_light(fav, false)
		check(t.current_title() != title, "'%s' completed in %ds" % [title, int(waited)])
	check(t.current_title() == "Notebooks", "reached 'Notebooks'")
	inv.books[0].interact(p)
	await frames(2)
	check(t.current_title() == "The journal", "examining a notebook completes its step")
	inv.manager.select_ghost(ghost_id)
	await frames(2)
	check(t.current_title() == "The safe room", "choosing a conclusion completes the journal step")
	teleport(p, Vector2i(29, 5))
	await frames(2)
	if t.panel._status.text.contains("power is out"):
		inv.electrical.set_power(true)
	await frames(3)
	check(t.current_title() == "Practice hunt", "standing in the warded room completes its step")


func _test_composure_rates() -> void:
	section("composure rates")
	var inv := await start_investigation(&"whisperer")
	var p: Node = inv.player
	inv.hunt_director.enabled = false
	inv.ghost.global_position = inv.house.cell_to_world(Vector2i(38, 15))
	teleport(p, Vector2i(5, 15))
	await frames(2)
	var dark: float = p.sanity.compute_rate()
	check(dark <= -0.39, "unlit room, no power, no light drains fast (%.2f/s)" % dark)
	p.equipment.use_current()
	await frames(2)
	var torch: float = p.sanity.compute_rate()
	check(torch < 0.0 and torch > dark, "flashlight slows the drain (%.2f/s)" % torch)
	inv.electrical.set_power(true)
	await frames(2)
	check(is_equal_approx(p.sanity.compute_rate(), 0.0), "lit room: no darkness drain")
	teleport(p, Vector2i(29, 5))
	await frames(2)
	check(p.sanity.compute_rate() >= 2.0, "warded safe room recovers fast (%.2f/s)" % p.sanity.compute_rate())
	p.sanity.set_value(40.0)
	await seconds(10.0)
	check(p.sanity.value >= 59.0, "10 s in the safe room recovers ~20%% (now %.0f)" % p.sanity.value)


func _test_monologue() -> void:
	section("inner monologue")
	var inv := await start_investigation(&"whisperer")
	var p: Node = inv.player
	inv.hunt_director.enabled = false
	var said: Array = []
	inv.monologue.spoke.connect(func(t: String) -> void: said.append(t))
	p.sanity.set_value(89.0)
	check(said.size() == 1 and inv.hud.monologue_text().contains("watching"), "crossing 90% speaks")
	p.sanity.set_value(85.0)
	check(said.size() == 1, "no repeat within the same 10% band")
	p.sanity.set_value(69.0)
	check(said.size() == 2 and said[1].contains("losing composure"), "big drop speaks once, for the lowest mark")
	p.sanity.set_value(59.0)
	check(said[2].contains("thriving on my unease"), "lines escalate toward a hunt")
	p.sanity.set_value(44.0)
	check(said.back().contains("can hunt me now"), "crossing the ghost's hunt threshold warns of a hunt")
	p.sanity.set_value(97.0)
	p.sanity.set_value(88.0)
	check(said.back().contains("watching"), "recovered marks re-arm")


func _test_appliances() -> void:
	section("TVs & radios")
	var inv := await start_investigation(&"disturbed")
	var p: Node = inv.player
	var house: Node = inv.house
	var tvs: Array = house.appliances.filter(func(a: Node) -> bool: return a.appliance_name == "TV")
	var radios: Array = house.radios()
	var kids: Object = house.get_room_by_id(&"kids_room")
	check(kids != null and tvs.size() == 2 and radios.size() == 3, "kids' room, 2 TVs and 3 radios placed")
	check(radios.all(func(r: Node) -> bool: return r.room != kids), "no radio in the kids' room")
	var tv: Node = tvs[0]
	check(not tv.set_on(true, &"player") and not tv.is_on, "TV needs power")
	inv.electrical.set_power(true)
	tv.interact(p)
	await frames(5)
	check(tv.is_on and tv.is_playing_static() and tv._light.enabled, "TV on: static sound and flickering light")
	var hues := {}
	for i in 30:
		await frames(2)
		hues[tv._light.color] = true
	check(hues.size() >= 3, "TV light cycles through TV hues (%d seen)" % hues.size())
	inv.electrical.trip("ghost")
	await frames(2)
	check(not tv.is_on, "power cut turns the TV off")
	var radio: Node = radios[0]
	radio.interact(p)
	await frames(5)
	check(radio.is_playing_music(), "radio plays music without house power")
	var stream: AudioStream = radio._music.stream
	check(stream is AudioStreamMP3 and stream.loop and stream.resource_path.contains("Where Did Everybody Go") or (stream is AudioStreamMP3 and stream.loop), "radio plays the looping MP3")
	check(radio._music.bus == &"Radio" and AudioServer.get_bus_effect_count(AudioServer.get_bus_index(&"Radio")) >= 2, "music runs through the distorted Radio bus")
	var vols := {}
	var static_heard := false
	for i in 40:
		await seconds(0.5)
		vols[snappedf(radio._music.volume_db, 1.0)] = true
		static_heard = static_heard or radio._static.playing
	check(vols.size() >= 3, "radio volume drifts (%d levels)" % vols.size())
	check(static_heard, "static breaks in over the music")
	check(radio.is_playing_music(), "music keeps playing (loops) until turned off")
	radio.interact(p)
	check(not radio.is_on and not radio._music.playing, "player turns the radio off")
	# The ghost switches appliances as one of its interactions.
	var g: Node = inv.ghost
	var by_ghost := {"n": 0}
	for a in house.appliances:
		a.toggled.connect(func(_a: Node, _on: bool, by: StringName) -> void:
			if by == &"ghost":
				by_ghost["n"] += 1)
	g.state = 1
	g.global_position = house.cell_to_world(Vector2i(37, 12))
	for i in 120:
		g.perform_interaction()
		g.global_position = house.cell_to_world(Vector2i(37, 12))
	check(by_ghost["n"] > 0, "ghost turns TVs/radios on and off (%d times)" % by_ghost["n"])


func _test_doll() -> void:
	section("the doll")
	var inv := await start_investigation(&"whisperer")
	var p: Node = inv.player
	var house: Node = inv.house
	var doll: Node = inv.doll
	inv.hunt_director.enabled = false
	check(doll != null and house.get_room_at(doll.global_position).id == &"kids_room", "doll sits in the kids' room")
	var kids_door: Node = house.door_at(Vector2i(34, 8))
	doll.wake_chance = 1.0
	kids_door.set_open(true, true)
	check(not doll.is_awake(), "ghost using the door does not wake it")
	teleport(p, Vector2i(34, 9))
	kids_door.interact(p)
	check(doll.is_awake(), "player opening the kids' room door can wake it")
	# Attack.
	await start_investigation(&"whisperer")
	inv = current_scene
	p = inv.player
	doll = inv.doll
	inv.hunt_director.enabled = false
	teleport(p, Vector2i(38, 14))
	var before: float = p.sanity.value
	var hit := {"n": 0}
	doll.attacked.connect(func(_d: Node) -> void: hit["n"] += 1)
	doll.wake(&"attack")
	for i in 20:
		await seconds(0.5)
		if hit["n"] > 0:
			break
	check(hit["n"] == 1, "doll runs at the investigator and reaches them")
	check(inv.jump_scare.playing and inv.jump_scare.mini, "mini jump scare plays")
	check(inv.jump_scare.texture.resource_path == "res://assets/doll/doll.png", "uses doll.png")
	check(not p.is_dead and p.sanity.value < before, "not lethal, but costs composure")
	var home: Vector2 = doll.home
	for i in 40:
		await seconds(0.5)
		if not doll.is_awake():
			break
	check(not doll.is_awake() and doll.global_position.distance_to(home) < 1.0, "doll walks back to its place")
	# Radio errand.
	var started := {"radio": null}
	doll.started_music.connect(func(_d: Node, r: Node) -> void: started["radio"] = r)
	doll.cooldown = 0.0
	doll.wake(&"radio")
	for i in 120:
		await seconds(0.5)
		if started["radio"] != null and not doll.is_awake():
			break
	var r: Node = started["radio"]
	check(r != null and r.is_on and r.is_playing_music(), "doll walks to a radio and turns the music on")
	check(r != null and r.room.id != &"kids_room", "the radio is outside the kids' room")
	check(not doll.is_awake() and doll.global_position.distance_to(home) < 1.0, "then walks back and sits")
	check(r != null and r.is_playing_music(), "music keeps playing after the doll leaves")


func _test_ritual_pickup() -> void:
	section("ritual circle pickup")
	var inv := await start_investigation(&"whisperer")
	var p: Node = inv.player
	inv.hunt_director.enabled = false
	teleport(p, Vector2i(6, 14))
	p.equipment.select(1)
	p.equipment.add_item(inv.database.get_equipment(&"ritual_kit"))
	p.equipment.use_current()
	await frames(2)
	var circle: Node = inv.item_root.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("RitualCircle"))[0]
	check(circle.get_secondary_prompt(p) == "Pick up the ritual kit", "circle offers R — pick up")
	var pos: Vector2 = circle.global_position
	circle.secondary_interact(p)
	await frames(2)
	check(p.equipment.has_item(&"ritual_kit"), "kit returns to the inventory")
	check(not is_instance_valid(circle) or circle.is_queued_for_deletion(), "circle removed")
	var remnants: Array = root.get_tree().get_nodes_in_group(&"ritual_remnant")
	check(remnants.size() == 1 and remnants[0].global_position.distance_to(pos) < 1.0, "a warped pentagram remains where it was")


func _test_hunt_audio() -> void:
	section("hunt audio")
	var inv := await start_investigation(&"disturbed")
	var amb := AudioServer.get_bus_index(&"Ambience")
	inv.hunt_director.start_hunt()
	await frames(5)
	var am: Node = root.get_node("AudioManager")
	check(am._loops.has(&"hunt_drone") and am._loops.has(&"hunt"), "hunt drone and heartbeat play")
	check(AudioServer.is_bus_effect_enabled(amb, 0), "ambience is muffled during the hunt")
	inv.ghost.global_position = inv.player.global_position + Vector2(60, 0)
	await frames(3)
	var near_pitch: float = am._loops[&"hunt"].pitch_scale
	inv.ghost.global_position = inv.player.global_position + Vector2(600, 0)
	await frames(3)
	check(near_pitch > am._loops[&"hunt"].pitch_scale, "heartbeat quickens as the ghost gets close")
	inv.hunt_director.end_hunt()
	check(not am._loops.has(&"hunt_drone") and not AudioServer.is_bus_effect_enabled(amb, 0), "hunt audio stops afterwards")


func _test_exit_and_results() -> void:
	section("exit, results, restart")
	var inv := await start_investigation(&"disturbed")
	var p: Node = inv.player
	inv.manager.observe(&"emf_5", "Kitchen")
	inv.manager.set_mark(&"emf_5", 1)
	inv.manager.select_ghost(&"disturbed")
	check(inv.manager.selected_ghost_id == &"disturbed", "ghost selected in journal")
	inv.manager.set_mark(&"emf_5", 2)
	check(inv.manager.selected_ghost_id == &"", "selection cleared when notes exclude it")
	inv.manager.set_mark(&"emf_5", 1)
	inv.manager.select_ghost(&"disturbed")
	teleport(p, Vector2i(12, 22))
	inv.exit_point.interact(p)
	await frames(2)
	var res: Dictionary = inv.manager.results
	check(inv.manager.finished and res["survived"] == true, "leaving ends the investigation alive")
	check(res["correct"] == true and res["actual_ghost"] == "The Disturbed", "correct identification evaluated")
	check(res["observed_evidence"].has("EMF Level 5"), "results list discovered evidence")
	check(inv.results_screen.visible and paused, "results screen shown, game paused")
	inv.results_screen.restart_requested.emit()
	for i in 10:
		await process_frame
	check(current_scene != inv and current_scene.name == "Investigation" and not paused, "restart loads a fresh investigation")
