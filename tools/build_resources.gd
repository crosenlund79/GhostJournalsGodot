extends SceneTree
## Authoring tool: (re)generates the data resources under res://resources/.
## Run:  godot --headless --path . -s res://tools/build_resources.gd
## The generated .tres files are the source of truth afterwards and can be
## edited in the Godot inspector; this script documents their initial values.


const GHOST_TOKEN := "res://assets/ghost/GhostToken.png"
const GHOST_CAUGHT := "res://assets/ghost/Ghost_caught_player.png"
const GHOST_SCREAM := "res://audio/Ghost_caught_player_scream.wav"


func _initialize() -> void:
	var evidence := _build_evidence()
	var ghosts := _build_ghosts()
	var equipment := _build_equipment()
	var balance := GameBalance.new()
	balance.darkness_drain = 0.30
	balance.flashlight_darkness_drain = 0.13
	balance.safe_room_recovery = 2.0
	balance.power_out_multiplier = 1.35
	balance.ghost_proximity_drain = 0.15
	_save(balance, "res://resources/balance/default_balance.tres")
	var db := GameDatabase.new()
	db.evidence = evidence
	db.ghosts = ghosts
	db.equipment = equipment
	db.balance = load("res://resources/balance/default_balance.tres")
	_save(db, "res://resources/game_database.tres")
	print("Resources generated.")
	quit()


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s: %s" % [path, err])
	else:
		print("saved ", path)


func _ev(id: String, name: String, short: String, desc: String, req: String, equip: String, note: String) -> EvidenceDefinition:
	var e := EvidenceDefinition.new()
	e.id = StringName(id)
	e.display_name = name
	e.short_name = short
	e.description = desc
	e.discovery_requirements = req
	e.equipment_id = StringName(equip)
	e.observation_note = note
	var path := "res://resources/evidence/%s.tres" % id
	_save(e, path)
	return load(path)


func _build_evidence() -> Array[EvidenceDefinition]:
	var out: Array[EvidenceDefinition] = []
	out.append(_ev("emf_5", "EMF Level 5", "EMF 5",
		"An electromagnetic spike at the reader's maximum level.",
		"Keep an EMF Reader switched on near places the ghost has just disturbed: doors, switches, knocked objects.",
		"emf_reader", "The EMF reader spiked to level 5 in the {room}."))
	out.append(_ev("uv_prints", "UV Handprints", "UV",
		"Fluorescent handprints left on surfaces the entity touched.",
		"Sweep a UV Flashlight over doors and light switches after they have moved.",
		"uv_flashlight", "Glowing handprints appeared under UV light in the {room}."))
	out.append(_ev("spirit_box", "Spirit Box Response", "Box",
		"A voice answering through the radio sweep.",
		"Switch on the Spirit Box close to the presence, in a room with its lights OFF, and wait.",
		"spirit_box", "A voice answered through the Spirit Box in the {room}: \"{detail}\""))
	out.append(_ev("orbs", "Ghost Orbs", "Orbs",
		"Small drifting lights visible only on camera.",
		"Record with the Video Camera in the room where the entity dwells.",
		"video_camera", "Drifting orbs appeared on camera in the {room}."))
	out.append(_ev("freezing", "Freezing Temperatures", "Freeze",
		"A room unnaturally cold, below 0 °C.",
		"Take Thermometer readings room by room. Cold is common near the entity; freezing is not.",
		"thermometer", "The thermometer read {detail} in the {room}."))
	out.append(_ev("writing", "Demonic Writing", "Writing",
		"Symbols scrawled into an old notebook.",
		"Old notebooks lie around the house. Check them again after activity nearby (E to examine).",
		"", "Something wrote in the notebook in the {room}."))
	return out


func _build_ghosts() -> Array[GhostDefinition]:
	var out: Array[GhostDefinition] = []
	var w := GhostDefinition.new()
	w.id = &"whisperer"
	w.display_name = "The Whisperer"
	w.description = "A patient presence that lingers in dark rooms and speaks to those who sit alone with it."
	w.behaviour_notes = "Prefers darker rooms. Whispers often. Interacts rarely. Manifests to people standing alone in darkness."
	w.evidence = [&"spirit_box", &"orbs", &"freezing"] as Array[StringName]
	w.roam_speed = 30.0
	w.hunt_speed = 76.0
	w.favorite_room_bias = 0.8
	w.darkness_preference = 0.9
	w.interaction_interval = Vector2(16.0, 28.0)
	w.door_weight = 0.5
	w.light_weight = 1.2
	w.object_weight = 1.0
	w.power_trip_weight = 0.08
	w.appliance_weight = 0.9
	w.manifestation_chance = 0.05
	w.darkness_manifest_bonus = 0.04
	w.whisper_interval = Vector2(14.0, 26.0)
	w.proximity_aggression = 1.0
	w.hunt_sanity_threshold = 45.0
	w.hunt_chance = 0.12
	w.hunt_duration = Vector2(20.0, 28.0)
	w.hunt_power_trip_chance = 0.15
	w.spirit_box_chance = 0.5
	w.spirit_box_phrases = PackedStringArray(["...here...", "...so cold...", "...behind you...", "...stay...", "...alone..."])
	w.voice_pitch = 0.85
	w.sprite = load(GHOST_TOKEN)
	w.caught_sprite = load(GHOST_CAUGHT)
	w.caught_sound = load(GHOST_SCREAM)
	_save(w, "res://resources/ghosts/whisperer.tres")
	out.append(load("res://resources/ghosts/whisperer.tres"))

	var d := GhostDefinition.new()
	d.id = &"disturbed"
	d.display_name = "The Disturbed"
	d.description = "A restless, violent thing that slams doors, kills the lights and resents company."
	d.behaviour_notes = "Interacts with doors constantly. Strong disturbances. More aggressive while you stay near it. Hunts readily."
	d.evidence = [&"emf_5", &"uv_prints", &"writing"] as Array[StringName]
	d.roam_speed = 42.0
	d.hunt_speed = 86.0
	d.favorite_room_bias = 0.65
	d.darkness_preference = 0.2
	d.interaction_interval = Vector2(7.0, 14.0)
	d.door_weight = 2.6
	d.light_weight = 1.0
	d.object_weight = 1.2
	d.power_trip_weight = 0.22
	d.appliance_weight = 1.5
	d.manifestation_chance = 0.045
	d.darkness_manifest_bonus = 0.0
	d.whisper_interval = Vector2.ZERO
	d.proximity_aggression = 1.6
	d.hunt_sanity_threshold = 58.0
	d.hunt_chance = 0.18
	d.hunt_duration = Vector2(24.0, 32.0)
	d.hunt_power_trip_chance = 0.35
	d.emf5_chance = 0.45
	d.uv_print_chance = 0.7
	d.writing_chance = 0.65
	d.voice_pitch = 1.15
	d.sprite = load(GHOST_TOKEN)
	d.caught_sprite = load(GHOST_CAUGHT)
	d.caught_sound = load(GHOST_SCREAM)
	_save(d, "res://resources/ghosts/disturbed.tres")
	out.append(load("res://resources/ghosts/disturbed.tres"))
	return out


func _eq(id: String, name: String, short: String, desc: String, hint: String) -> EquipmentDefinition:
	var e := EquipmentDefinition.new()
	e.id = StringName(id)
	e.display_name = name
	e.short_name = short
	e.description = desc
	e.use_hint = hint
	e.scene = load("res://scenes/equipment/%s.tscn" % id)
	var path := "res://resources/equipment/%s.tres" % id
	_save(e, path)
	return load(path)


func _build_equipment() -> Array[EquipmentDefinition]:
	var out: Array[EquipmentDefinition] = []
	out.append(_eq("flashlight", "Flashlight", "Torch", "A dependable beam. Darkness stays dark outside it.", "toggle"))
	out.append(_eq("uv_flashlight", "UV Flashlight", "UV", "Ultraviolet beam that reveals handprints.", "toggle"))
	out.append(_eq("emf_reader", "EMF Reader", "EMF", "Detects electromagnetic disturbances (levels 1-5).", "toggle"))
	out.append(_eq("spirit_box", "Spirit Box", "Box", "Radio sweep the dead sometimes speak through.", "toggle"))
	out.append(_eq("video_camera", "Video Camera", "Cam", "Night-vision camera. Some things only show on tape.", "record"))
	out.append(_eq("thermometer", "Thermometer", "Temp", "Reads the room temperature.", "toggle"))
	out.append(_eq("ritual_kit", "Ritual Kit", "Rite", "Salt and candles for the rite of expulsion.", "lay circle"))
	return out
