extends SceneTree
## Balance probe: lets the real ghost AI run unattended while a passive
## investigator waits in the ghost's favourite room, and reports when each
## evidence type first became detectable. No debug shortcuts are used.
##
## Run: godot --headless --path . --fixed-fps 60 -s res://tests/balance_probe.gd

const SIM_SECONDS := 240.0
const RUNS_PER_GHOST := 4

var gm: Node


func _initialize() -> void:
	gm = root.get_node("GameManager")
	_run.call_deferred()


func _run() -> void:
	for ghost_id in [&"whisperer", &"disturbed"]:
		for run in RUNS_PER_GHOST:
			await _probe(ghost_id, run)
	quit()


func _probe(ghost_id: StringName, run: int) -> void:
	gm.set("forced_ghost_id", ghost_id)
	gm.call("start_investigation")
	for i in 30:
		await process_frame
		if current_scene and current_scene.name == "Investigation" and current_scene.get("player") != null:
			break
	await physics_frame
	var inv := current_scene
	var p: Node = inv.player
	var g: Node = inv.ghost
	var house: Node = inv.house
	# Player stands in the favourite room's walkable cell nearest its centre, power off.
	var center: Vector2 = g.favorite_room.center_world()
	var cell: Vector2i = house.nearest_walkable_cell(house.world_to_cell(center))
	p.global_position = house.cell_to_world(cell)
	# Equip the relevant tools: EMF stays on (it reads passively); the thermometer
	# and spirit box are sampled directly so one investigator can "use" all.
	p.equipment.select(1)
	p.equipment.add_item(inv.database.get_equipment(&"emf_reader"))
	p.equipment.use_current()
	var first := {}
	var hunts := 0
	var first_hunt := -1.0
	# Lambdas capture locals by value, so count through a dictionary.
	var counter := {"manifests": 0}
	var was_hunting := false
	g.manifested.connect(func(_seen: bool) -> void: counter["manifests"] += 1)
	var t := 0.0
	var step := 1.0 / 60.0
	while t < SIM_SECONDS and not p.is_dead:
		await physics_frame
		t += step
		if inv.hunt_director.is_hunting and not was_hunting:
			hunts += 1
			if first_hunt < 0.0:
				first_hunt = t
		was_hunting = inv.hunt_director.is_hunting
		# Keep the investigator in place (a hunt may have moved nothing, but be safe).
		for id in inv.manager.observed.keys():
			if not first.has(id):
				first[id] = t
		if not first.has(&"freezing_possible") and g.favorite_room.temperature < 0.0:
			first[&"freezing_possible"] = t
		if not first.has(&"uv_possible") and not root.get_tree().get_nodes_in_group(&"uv_print").is_empty():
			first[&"uv_possible"] = t
		if not first.has(&"writing_possible") and inv.books.any(func(b: Node) -> bool: return b.written):
			first[&"writing_possible"] = t
		if not first.has(&"spirit_possible") and int(t * 60.0) % 190 == 0 and g.try_spirit_box_response(p) != "":
			first[&"spirit_possible"] = t
	var parts := PackedStringArray()
	for k in first.keys():
		parts.append("%s@%ds" % [k, int(first[k])])
	print("%s run %d | fav=%s | %s | hunts=%d (first %ds) manifests=%d sanity=%.0f dead=%s at %ds" % [
		ghost_id, run, g.favorite_room.display_name, ", ".join(parts), hunts, int(first_hunt), counter["manifests"], p.sanity.value, p.is_dead, int(t)])
