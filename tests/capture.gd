extends SceneTree
## Renders screenshots of scripted situations (needs a display; use xvfb-run).
## Run: xvfb-run -s "-screen 0 1280x720x24" godot --path . -s res://tests/capture.gd -- <scenario>

var _frames: int = 0
var _inv: Node
var _scenario: String = "overview"
var _shots: Array = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/output"))
	var ignore := FileAccess.open("res://tests/output/.gdignore", FileAccess.WRITE)
	ignore.close()
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_scenario = args[0]
	if _scenario == "menu":
		change_scene_to_file("res://scenes/main/main_menu.tscn")
	elif _scenario == "tutorial":
		var gm: Node = root.get_node("GameManager")
		gm.set("forced_ghost_id", &"whisperer")
		gm.call_deferred("start_tutorial")
	else:
		var gm: Node = root.get_node("GameManager")
		gm.set("forced_ghost_id", &"disturbed" if _scenario.ends_with("_d") else &"whisperer")
		gm.set("debug_enabled", true)
		change_scene_to_file("res://scenes/main/investigation.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _inv == null and current_scene != null and current_scene.name == "Investigation":
		_inv = current_scene
		_setup()
	for shot in _shots.duplicate():
		if _frames == shot[0]:
			if shot.size() > 2 and shot[2] is Callable:
				(shot[2] as Callable).call()
			if shot[1] != "":
				_take(shot[1])
	if _scenario == "menu" and _frames == 30:
		_take("menu")
	if _frames > 520 or (_scenario == "menu" and _frames > 40):
		quit()
	return false


func _take(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("res://tests/output/%s.png" % shot_name)
	print("saved ", shot_name)


func _setup() -> void:
	var p: Node = _inv.player
	var house: Node = _inv.house
	match _scenario:
		"scare":
			_shots = [[20, "", func() -> void:
					_inv.electrical.set_power(true)
					p.global_position = house.cell_to_world(Vector2i(5, 15))
					p.aim_override = Vector2.RIGHT
					_inv.ghost._state_timer = 0.0],
				[25, "", func() -> void:
					_inv.hunt_director.start_hunt()
					_inv.ghost._hunt_grace = 99.0
					_inv.ghost.global_position = p.global_position + Vector2(110, -40)],
				[40, "scare_0_before"],
				[42, "", func() -> void: _inv.ghost._catch_player()],
				[50, "scare_1_rush"],
				[55, "scare_2_rush_late"],
				[63, "scare_3_covered"],
				[78, "scare_4_fog"],
				[100, "scare_5_fog_clearing"],
				[110, "scare_6_fog_thinning"],
				[125, "scare_7_fog_clearing"],
				[145, "scare_8_death_screen"],
			]
		"ghost":
			var step := func(dir: Vector2) -> void:
				_inv.ghost.global_position += dir
			_shots = [[20, "", func() -> void:
					_inv.electrical.set_power(true)
					_inv.hunt_director.enabled = false
					p.global_position = house.cell_to_world(Vector2i(4, 15))
					p.aim_override = Vector2.RIGHT
					_inv.ghost._state_timer = 0.0],
				[25, "", func() -> void:
					_inv.ghost.start_manifestation()
					_inv.ghost._state_timer = 99.0
					_inv.ghost.global_position = house.cell_to_world(Vector2i(14, 13))
					_inv.ghost._last_position = _inv.ghost.global_position],
			]
			for i in range(26, 90):
				_shots.append([i, "", step.bind(Vector2(-2.2, 0.9))])
			_shots.append([90, "ghost_lit_trail"])
			_shots.append([92, "", func() -> void:
				_inv.electrical.set_power(false)
				p.equipment.use_current()
				_inv.ghost.global_position = house.cell_to_world(Vector2i(14, 17))
				_inv.ghost._last_position = _inv.ghost.global_position])
			for i in range(93, 150):
				_shots.append([i, "", step.bind(Vector2(-2.0, -1.2))])
			_shots.append([150, "ghost_dark_trail"])
		"tutorial":
			_shots = [[30, "tutorial_start"],
				[35, "", func() -> void:
					while _inv.tutorial.current_title() != "Restore the power":
						_inv.tutorial.skip()
					p.global_position = house.cell_to_world(Vector2i(22, 10))
					p.aim_override = Vector2.UP
					p.equipment.use_current()],
				[80, "tutorial_fuse"],
				[85, "", func() -> void:
					_inv.electrical.set_power(true)
					while _inv.tutorial.current_title() != "Spirit Box":
						_inv.tutorial.skip()
					p.equipment.select(1)
					p.equipment.add_item(_inv.database.get_equipment(&"spirit_box"))
					p.global_position = _inv.ghost.favorite_room.center_world() + Vector2(0, 30)],
				[130, "tutorial_status"],
			]
		"overview", "overview_d":
			_shots = [[20, "start_yard"],
				[30, "", func() -> void:
					p.global_position = house.cell_to_world(Vector2i(19, 15))
					p.aim_override = Vector2.UP
					p.equipment.use_current()],
				[60, "foyer_dark_flashlight"],
				[70, "", func() -> void:
					_inv.electrical.set_power(true)
					p.global_position = house.cell_to_world(Vector2i(8, 15))
					p.aim_override = Vector2.RIGHT],
				[110, "living_room_lit"],
				[120, "", func() -> void:
					p.camera.zoom = Vector2(0.75, 0.75)
					p.global_position = house.cell_to_world(Vector2i(22, 12))],
				[170, "house_overview_power"],
				[180, "", func() -> void:
					_inv.electrical.set_power(false)],
				[220, "house_overview_dark"],
				[230, "", func() -> void:
					p.camera.zoom = Vector2(2, 2)
					p.global_position = house.cell_to_world(Vector2i(23, 4))
					p.aim_override = Vector2.UP
					_inv.journal.open()],
				[260, "journal"],
				[270, "", func() -> void:
					_inv.journal.close()
					_inv.electrical.set_power(true)
					p.global_position = house.cell_to_world(Vector2i(6, 15))
					p.aim_override = Vector2.RIGHT
					_inv.ghost._state_timer = 0.0],
				[275, "", func() -> void:
					_inv.ghost.start_manifestation()
					_inv.ghost.global_position = p.global_position + Vector2(110, 10)],
				[300, "manifestation"],
				[305, "", func() -> void:
					_inv.ghost.spawn_uv_print(p.global_position + Vector2(60, -10)).global_position = p.global_position + Vector2(60, -10)
					_inv.electrical.set_power(false)
					p.equipment.select(1)
					p.equipment.add_item(_inv.database.get_equipment(&"uv_flashlight"))
					p.equipment.use_current()],
				[330, "uv_print"],
				[332, "", func() -> void:
					p.equipment.use_current()
					p.equipment.select(2)
					p.equipment.add_item(_inv.database.get_equipment(&"video_camera"))
					p.equipment.use_current()
					var orbs: Array = _inv.get_tree().get_nodes_in_group(&"ghost_orb")
					if not orbs.is_empty():
						orbs[0].global_position = p.global_position + Vector2(80, 5)
						orbs[0]._target = orbs[0].global_position],
				[350, "camera_orb"],
				[352, "", func() -> void:
					p.equipment.use_current()
					_inv.electrical.set_power(true)
					_inv.debug_overlay.visible = false
					_inv.hunt_director.start_hunt()
					_inv.electrical.set_power(true)
					_inv.ghost.global_position = p.global_position + Vector2(70, 0)],
				[372, "hunt"],
				[374, "", func() -> void:
					_inv.ghost.global_position = p.global_position + Vector2(12, 0)
					_inv.ghost._hunt_grace = 0.0],
				[392, "caught"],
				[500, "death"],
				[505, "", func() -> void: _inv._show_results()],
				[515, "results"],
			]
