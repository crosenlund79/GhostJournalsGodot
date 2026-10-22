class_name TutorialDirector
extends Node
## Guided "Learn to Play" investigation. Runs on top of a normal
## investigation: the ghost behaves exactly like in a real case (it is only
## flagged harmless), and each step watches real game state to decide when
## the player has learned something. Tab skips a step.

signal step_changed(index: int)
signal finished_all

var inv: Investigation
var steps: Array[Dictionary] = []
var index: int = 0
var panel: TutorialPanel
var marker: TutorialMarker

var _step_time: float = 0.0
var _acc: float = 0.0
var _switch_uses: int = 0
var _books_read: int = 0
var _start_pos := Vector2.ZERO
var _max_emf: int = 0
var _hunt_seen: bool = false
var _hunt_countdown: float = -1.0


func setup(investigation: Investigation) -> void:
	inv = investigation
	_start_pos = inv.player.global_position
	for sw in inv.house.light_switches:
		sw.toggled_by.connect(func(_a: Node, _on: bool) -> void: _switch_uses += 1)
	for book in inv.books:
		book.interacted.connect(func(_a: Node) -> void: _books_read += 1)
	inv.hunt_director.hunt_started.connect(func() -> void: _hunt_seen = true)
	# The tree pauses on the results screen, so close out the tutorial here.
	inv.manager.investigation_finished.connect(func(_r: Dictionary) -> void:
		if not is_complete():
			index = steps.size()
			marker.target = null
			panel.visible = false
			finished_all.emit())
	_build_steps()
	panel = TutorialPanel.new()
	panel.name = "TutorialPanel"
	inv.add_child(panel)
	marker = TutorialMarker.new()
	marker.name = "TutorialMarker"
	marker.player = inv.player
	inv.world.add_child(marker)
	_enter(0)


# --- Step data ------------------------------------------------------------------

func _step(title: String, text: String, done: Callable, target: Callable = Callable(),
		on_enter: Callable = Callable(), on_done: Callable = Callable()) -> void:
	steps.append({"title": title, "text": text, "done": done, "target": target, "enter": on_enter, "on_done": on_done})


func _build_steps() -> void:
	var p := inv.player
	var fav_room := inv.ghost.favorite_room
	_step("Welcome, investigator",
		"Move with W A S D and aim with the mouse. Walk over to the equipment racks beside the van.\nThe entity here behaves like any other — but in training it cannot kill you.",
		func() -> bool: return p.global_position.distance_to(_start_pos) > 48.0,
		func() -> Variant: return _rack_center())
	_step("Flashlight",
		"Your flashlight is in slot 1. Press F to switch it on. Light keeps your composure from slipping, but darkness outside the beam stays dark.",
		func() -> bool: return _held_active(&"flashlight"))
	_step("Take your equipment",
		"Take the Thermometer, EMF Reader and UV Flashlight from the racks (E).\nYou carry four items; 1–4 selects one. Taking an item with full hands swaps it with the held one.",
		func() -> bool: return _has_all([&"thermometer", &"emf_reader", &"uv_flashlight"]),
		func() -> Variant: return _nearest_pickup([&"thermometer", &"emf_reader", &"uv_flashlight"]))
	_step("Enter the house",
		"Open the front door with E and step inside. The house has no power — keep your light handy.",
		func() -> bool: return inv.house.is_indoors(p.global_position),
		func() -> Variant: return inv.house.front_door.global_position)
	_step("Restore the power",
		"Find the fuse box in the Utility Room and hold E to throw the breaker. Power lights the rooms and wards the safe room. Ghosts can cut it again.",
		func() -> bool: return inv.electrical.is_powered(),
		func() -> Variant: return inv.fuse_box.global_position)
	_step("Light switches",
		"Every room has a switch by its door. Flip one (E). Dark rooms drain your composure; some evidence only appears in the dark.",
		func() -> bool: return _switch_uses > 0,
		func() -> Variant: return _nearest_switch())
	_step("Thermometer",
		"Select the Thermometer (number key) and press F. Walk room to room: rooms sit around 17–20 °C. Where it is cold, something dwells. Below 0 °C is evidence: Freezing Temperatures.",
		func() -> bool: return _held_active(&"thermometer") and inv.house.get_room_at(p.global_position) == fav_room,
		func() -> Variant: return fav_room.center_world() if _step_time > 45.0 else null,
		Callable(),
		func() -> void: inv.manager.notify("The %s is cold. This is where it dwells." % fav_room.display_name, &"evidence"))
	_step("EMF Reader",
		"Hold the EMF Reader and switch it on in the %s. Wait for the entity to touch something — a door, a switch, a knock. Disturbances read 2–4. A reading of 5 is evidence." % fav_room.display_name,
		func() -> bool: return _max_emf >= 2 or inv.manager.observed.has(&"emf_5"),
		func() -> Variant: return _latest_emf(),
		func() -> void: _nudge_ghost())
	_step("UV Flashlight",
		"Switch on the UV Flashlight and sweep it over doors and switches the entity touched. Some ghosts leave glowing handprints; they are invisible in normal light.\n(No prints after a good look? This ghost may not leave them — that is evidence too.)",
		func() -> bool: return inv.manager.observed.has(&"uv_prints") or _accumulate(_held_active(&"uv_flashlight") and inv.house.is_indoors(p.global_position), 8.0),
		func() -> Variant: return _latest_emf())
	_step("Back to the van",
		"Return to the van and swap for the Spirit Box and the Video Camera. Leaving equipment behind is part of the job.",
		func() -> bool: return _has_all([&"spirit_box", &"video_camera"]),
		func() -> Variant: return _nearest_pickup([&"spirit_box", &"video_camera"]))
	_step("Spirit Box",
		"Go to the %s, switch its lights OFF, then turn on the Spirit Box (F) and wait. Some entities answer through the static — but never in a lit room." % fav_room.display_name,
		func() -> bool: return inv.manager.observed.has(&"spirit_box") or _accumulate(
			_held_active(&"spirit_box") and inv.house.get_room_at(p.global_position) == fav_room and not inv.house.is_room_lit(fav_room), 12.0),
		func() -> Variant: return fav_room.center_world(),
		func() -> void: _nudge_ghost())
	_step("Video Camera",
		"Record with the Video Camera (F) in the %s and pan around. Ghost Orbs only show up on camera. The camera's night vision also helps you see in the dark." % fav_room.display_name,
		func() -> bool: return inv.manager.observed.has(&"orbs") or _accumulate(
			_held_active(&"video_camera") and inv.house.get_room_at(p.global_position) == fav_room, 8.0),
		func() -> Variant: return fav_room.center_world())
	_step("Notebooks",
		"Old notebooks lie around the house. Examine one with E. Some entities scrawl Demonic Writing in them — check again after activity nearby.",
		func() -> bool: return _books_read > 0,
		func() -> Variant: return _nearest_book())
	_step("The journal",
		"Press J. Your field notes list what your equipment detected. Click evidence to mark it confirmed (+) or ruled out (–); entities that don't fit are excluded. Select your conclusion, then close the journal.",
		func() -> bool: return inv.manager.selected_ghost_id != &"" and not inv.journal.is_open)
	_step("The safe room",
		"While the power is on, the warding lamp in the Storage Room keeps the entity out. Step inside. Your composure recovers here.",
		func() -> bool: return inv.safe_room.is_position_protected(p.global_position),
		func() -> Variant: return inv.warding_lamp.global_position)
	_step("Practice hunt",
		"When composure runs low, the entity hunts: lights flicker, the front door locks, you hear its footsteps. A practice hunt begins in a few seconds. Leave this room and survive it — break line of sight and hide, or come back here. It cannot kill you in training.",
		func() -> bool: return _hunt_seen and not inv.hunt_director.is_hunting,
		Callable(),
		func() -> void:
			_hunt_seen = false
			_hunt_countdown = 8.0)
	_step("Exorcism (optional)",
		"Take the Ritual Kit from the van. In the %s press F to lay the circle, then hold E while the entity is near it. The rite needs its name in your journal — the wrong name enrages it. Press Tab to skip." % fav_room.display_name,
		func() -> bool: return inv.manager.exorcism_result != &"not_attempted",
		func() -> Variant: return _nearest_pickup([&"ritual_kit"]) if not inv.player.equipment.has_item(&"ritual_kit") else fav_room.center_world())
	_step("Leave",
		"That's the whole job. Return to the van door and hold E to end the investigation. The case file will judge your conclusion.",
		func() -> bool: return inv.manager.finished,
		func() -> Variant: return inv.exit_point.global_position)


# --- Flow -------------------------------------------------------------------------

func _enter(i: int) -> void:
	index = i
	_step_time = 0.0
	_acc = 0.0
	var s := steps[index]
	var enter: Callable = s["enter"]
	if enter.is_valid():
		enter.call()
	panel.show_step(index, steps.size(), s["title"], s["text"])
	step_changed.emit(index)


func current_title() -> String:
	return steps[index]["title"] if index < steps.size() else ""


func is_complete() -> bool:
	return index >= steps.size()


func skip() -> void:
	if is_complete():
		return
	_advance(false)


func _advance(completed: bool) -> void:
	var on_done: Callable = steps[index]["on_done"]
	if completed:
		AudioManager.play(&"evidence_cue", -10.0, 1.4)
		if on_done.is_valid():
			on_done.call()
	if index + 1 >= steps.size():
		index = steps.size()
		panel.show_done()
		marker.target = null
		finished_all.emit()
		return
	_enter(index + 1)


func _process(delta: float) -> void:
	if inv == null or is_complete():
		return
	_step_time += delta
	_track_emf()
	if _hunt_countdown >= 0.0:
		_hunt_countdown -= delta
		if _hunt_countdown < 0.0 and not inv.hunt_director.is_hunting and inv.ghost.is_active():
			inv.hunt_director.start_hunt()
	var s := steps[index]
	var target: Callable = s["target"]
	marker.target = target.call() if target.is_valid() else null
	panel.set_status(_status_hint())
	var done: Callable = s["done"]
	if done.call():
		_advance(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"tutorial_skip") and not inv.manager.finished:
		skip()
		get_viewport().set_input_as_handled()


## Situational hints, so a step never stalls silently when the ghost
## (behaving normally) undoes something the player did.
func _status_hint() -> String:
	var title := current_title()
	var p := inv.player
	var fav := inv.ghost.favorite_room
	var here := inv.house.get_room_at(p.global_position)
	var needs_power := ["Light switches", "The safe room"]
	if needs_power.has(title) and not inv.electrical.is_powered():
		return "The power is out. Restore it at the fuse box in the Utility Room."
	match title:
		"Thermometer", "EMF Reader", "UV Flashlight", "Spirit Box", "Video Camera":
			var tool: StringName = {"Thermometer": &"thermometer", "EMF Reader": &"emf_reader", "UV Flashlight": &"uv_flashlight",
				"Spirit Box": &"spirit_box", "Video Camera": &"video_camera"}[title]
			if not p.equipment.has_item(tool):
				return "You are not carrying it. Fetch it from the van."
			if not _held_active(tool):
				return "Select it with its number key, then press F to switch it on."
			if title == "Spirit Box" and here == fav and inv.house.is_room_lit(fav):
				return "The lights in the %s are on. Switch them off." % fav.display_name
			if title != "Thermometer" and title != "UV Flashlight" and here != fav:
				return "Go to the %s." % fav.display_name
			if title == "EMF Reader" and _latest_emf() != null:
				return "Something was just disturbed. Follow the marker."
		"Practice hunt":
			if _hunt_countdown >= 0.0:
				return "The hunt begins in %d..." % ceili(_hunt_countdown)
			if inv.hunt_director.is_hunting:
				return "It is hunting. Hide!"
	return ""


# --- Helpers ----------------------------------------------------------------------

func _held_active(item_id: StringName) -> bool:
	return inv.player.equipment.active_item(item_id) != null


func _has_all(ids: Array[StringName]) -> bool:
	for id in ids:
		if not inv.player.equipment.has_item(id):
			return false
	return true


## Accumulates time while a condition holds; true once it reaches `seconds`.
func _accumulate(condition: bool, seconds: float) -> bool:
	if condition:
		_acc += get_process_delta_time()
	return _acc >= seconds


func _track_emf() -> void:
	var item := inv.player.equipment.get_current()
	if item is EmfReader and item.active:
		_max_emf = maxi(_max_emf, (item as EmfReader).level)


func _nudge_ghost() -> void:
	# Only shortens the wait for its next normal interaction.
	inv.ghost._interaction_timer = minf(inv.ghost._interaction_timer, 6.0)


func _rack_center() -> Variant:
	var slots: Array = inv.house.layout["rack_slots"]
	return inv.house.cell_to_world(Vector2i(slots[1][0], slots[1][1])) + Vector2(0, InkStyle.TILE)


func _nearest_pickup(ids: Array[StringName]) -> Variant:
	var best: Variant = null
	var best_d := INF
	for node in inv.item_root.get_children():
		var pk := node as EquipmentPickup
		if pk == null or pk.definition == null or not ids.has(pk.definition.id):
			continue
		if inv.player.equipment.has_item(pk.definition.id):
			continue
		var d := pk.global_position.distance_to(inv.player.global_position)
		if d < best_d:
			best_d = d
			best = pk.global_position
	return best


func _nearest_switch() -> Variant:
	var best: Variant = null
	var best_d := INF
	for sw in inv.house.light_switches:
		var d := sw.global_position.distance_to(inv.player.global_position)
		if d < best_d:
			best_d = d
			best = sw.global_position
	return best


func _nearest_book() -> Variant:
	var best: Variant = null
	var best_d := INF
	for b in inv.books:
		var d := b.global_position.distance_to(inv.player.global_position)
		if d < best_d:
			best_d = d
			best = b.global_position
	return best


## Where the entity most recently disturbed something (or null).
func _latest_emf() -> Variant:
	var sources := get_tree().get_nodes_in_group(&"emf_source")
	if sources.is_empty():
		return null
	return (sources.back() as Node2D).global_position
