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
	await _test_hunt_kills_player()
	await _test_safe_room_protects()
	await _test_exorcism()
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
	check(doors == 10, "10 doors (9 interior + front)")
	check(data["rooms"].size() == 8, "8 named rooms")


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
	check(g.caught_player and g.visual.horror, "catch triggers the horror transformation")
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
