class_name House
extends Node2D
## Builds a house from layout data (see [OldHouseLayout]) and answers spatial
## questions: which room a point is in, whether it is lit, ghost navigation.
##
## Generation is fully data-driven: walls, collision, light occluders, doors,
## furniture, room lights and the navigation grid all come from the layout.

signal lights_changed

# Loaded at build time (not preloaded) to avoid a cyclic dependency: these
# scenes' scripts reference House constants.
const DOOR_SCENE_PATH := "res://scenes/environment/door.tscn"
const FURNITURE_SCENE_PATH := "res://scenes/environment/furniture.tscn"
const LIGHT_SWITCH_SCENE_PATH := "res://scenes/environment/light_switch.tscn"

const TILE := InkStyle.TILE
const SOLID_CHARS := "#X"
const WALL_LAYER := 1
const FURNITURE_LAYER := 2

var layout: Dictionary = {}
var grid: PackedStringArray = PackedStringArray()
var width: int = 0
var height: int = 0
var rooms: Dictionary = {}  # key -> RoomData
var room_list: Array[RoomData] = []
var safe_room: RoomData
var outdoors: RoomData
var doors: Dictionary = {}  # Vector2i -> Door
var front_door: Door
var furniture_cells: Dictionary = {}  # Vector2i -> type
var light_switches: Array[LightSwitch] = []
var astar := AStarGrid2D.new()
var electrical: ElectricalSystem

var _cell_room: Dictionary = {}
var _blocked_rooms: Dictionary = {}
var _light_texture: Texture2D

var floor_layer: Node2D
var wall_layer: Node2D
var furniture_root: Node2D
var door_root: Node2D
var light_root: Node2D
var object_root: Node2D


func build(layout_data: Dictionary, electrical_system: ElectricalSystem) -> void:
	layout = layout_data
	electrical = electrical_system
	grid = PackedStringArray(layout["grid"])
	height = grid.size()
	width = grid[0].length()
	_light_texture = _make_light_texture()
	_build_rooms()
	_build_visual_layers()
	_build_walls()
	_build_doors()
	_build_furniture()
	_build_room_lights()
	_build_switches()
	_build_navigation()
	_link_neighbors()
	if electrical:
		electrical.power_changed.connect(func(_on: bool, _reason: String) -> void: refresh_lights())
	refresh_lights()


func _exit_tree() -> void:
	# RoomData objects reference each other as neighbours; break the cycle.
	for room in room_list:
		room.neighbors.clear()
		room.lights.clear()


# --- Construction -------------------------------------------------------------

func _build_rooms() -> void:
	var defs: Dictionary = layout["rooms"]
	var outdoor_key: String = layout.get("outdoor_key", "O")
	for y in height:
		for x in width:
			var c := grid[y][x]
			if c in "#XDF ":
				continue
			var room: RoomData = rooms.get(c)
			if room == null:
				room = RoomData.new()
				room.key = c
				if c == outdoor_key:
					room.id = &"outside"
					room.display_name = "Outside"
					room.floor_type = &"grass"
					room.is_outdoors = true
					room.can_be_favorite = false
					room.base_temperature = 9.0
					room.light_energy = 0.0
					outdoors = room
				else:
					var d: Dictionary = defs.get(c, {})
					room.id = StringName(d.get("id", "room_%s" % c))
					room.display_name = d.get("name", "Room")
					room.floor_type = StringName(d.get("floor", "wood"))
					room.light_energy = d.get("light", 0.8)
					room.base_temperature = d.get("temp", 18.0)
					room.can_be_favorite = d.get("favorite", true)
					var sw: Array = d.get("switch", [])
					if sw.size() == 2:
						room.switch_cell = Vector2i(sw[0], sw[1])
				room.temperature = room.base_temperature
				rooms[c] = room
				room_list.append(room)
			room.cells.append(Vector2i(x, y))
			_cell_room[Vector2i(x, y)] = room
	for room in room_list:
		var minc := Vector2i(width, height)
		var maxc := Vector2i(-1, -1)
		for cell in room.cells:
			minc = Vector2i(mini(minc.x, cell.x), mini(minc.y, cell.y))
			maxc = Vector2i(maxi(maxc.x, cell.x), maxi(maxc.y, cell.y))
		room.bounds = Rect2i(minc, maxc - minc + Vector2i.ONE)
	var safe_key: String = layout.get("safe_room", "")
	if rooms.has(safe_key):
		safe_room = rooms[safe_key]
		safe_room.is_safe_room = true
		safe_room.can_be_favorite = false


func _build_visual_layers() -> void:
	floor_layer = preload("res://scripts/environment/floor_layer.gd").new()
	floor_layer.name = "Floor"
	floor_layer.z_index = -20
	floor_layer.house = self
	add_child(floor_layer)
	wall_layer = preload("res://scripts/environment/wall_layer.gd").new()
	wall_layer.name = "Walls"
	wall_layer.z_index = 10
	wall_layer.house = self
	add_child(wall_layer)
	furniture_root = Node2D.new()
	furniture_root.name = "Furniture"
	add_child(furniture_root)
	door_root = Node2D.new()
	door_root.name = "Doors"
	door_root.z_index = 8
	add_child(door_root)
	light_root = Node2D.new()
	light_root.name = "RoomLights"
	add_child(light_root)
	object_root = Node2D.new()
	object_root.name = "Objects"
	add_child(object_root)


## Merges wall cells into horizontal runs; each run becomes one collision
## rectangle and (for real walls) one light occluder.
func _build_walls() -> void:
	var body := StaticBody2D.new()
	body.name = "WallCollision"
	body.collision_layer = WALL_LAYER
	body.collision_mask = 0
	add_child(body)
	for y in height:
		var x := 0
		while x < width:
			var c := grid[y][x]
			if c in SOLID_CHARS:
				var start := x
				while x < width and grid[y][x] == c:
					x += 1
				var rect := Rect2(Vector2(start * TILE, y * TILE), Vector2((x - start) * TILE, TILE))
				var shape := CollisionShape2D.new()
				var rs := RectangleShape2D.new()
				rs.size = rect.size
				shape.shape = rs
				shape.position = rect.get_center()
				body.add_child(shape)
				if c == "#":
					var occ := LightOccluder2D.new()
					var poly := OccluderPolygon2D.new()
					poly.polygon = InkStyle.rect_points(rect)
					occ.occluder = poly
					add_child(occ)
			else:
				x += 1
	# Invisible boundary around the whole map.
	var bounds := Rect2(Vector2.ZERO, Vector2(width * TILE, height * TILE))
	for r in [Rect2(bounds.position - Vector2(TILE, TILE), Vector2(bounds.size.x + TILE * 2, TILE)),
			Rect2(Vector2(-TILE, bounds.end.y), Vector2(bounds.size.x + TILE * 2, TILE)),
			Rect2(Vector2(-TILE, 0), Vector2(TILE, bounds.size.y)),
			Rect2(Vector2(bounds.end.x, 0), Vector2(TILE, bounds.size.y))]:
		var shape := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = r.size
		shape.shape = rs
		shape.position = r.get_center()
		body.add_child(shape)


func _build_doors() -> void:
	var door_scene: PackedScene = load(DOOR_SCENE_PATH)
	for y in height:
		for x in width:
			var c := grid[y][x]
			if c != "D" and c != "F":
				continue
			var door: Door = door_scene.instantiate()
			var horizontal_wall := _is_wall(x - 1, y) and _is_wall(x + 1, y)
			door.orientation = Door.DoorAxis.HORIZONTAL if horizontal_wall else Door.DoorAxis.VERTICAL
			door.is_front_door = c == "F"
			door.cell = Vector2i(x, y)
			door.position = cell_to_world(Vector2i(x, y))
			door.name = "FrontDoor" if c == "F" else "Door_%d_%d" % [x, y]
			door_root.add_child(door)
			doors[Vector2i(x, y)] = door
			if c == "F":
				front_door = door


func _build_furniture() -> void:
	var furniture_scene: PackedScene = load(FURNITURE_SCENE_PATH)
	var index := 0
	for entry in layout.get("furniture", []):
		var f: Furniture = furniture_scene.instantiate()
		f.furniture_type = StringName(entry[0])
		var cell_rect := Rect2i(entry[1], entry[2], entry[3], entry[4])
		f.setup(cell_rect, index)
		furniture_root.add_child(f)
		if f.blocks_movement():
			for yy in range(cell_rect.position.y, cell_rect.end.y):
				for xx in range(cell_rect.position.x, cell_rect.end.x):
					furniture_cells[Vector2i(xx, yy)] = f.furniture_type
		index += 1


func _build_room_lights() -> void:
	var defs: Dictionary = layout["rooms"]
	for key in defs.keys():
		var room: RoomData = rooms.get(key)
		if room == null:
			continue
		var d: Dictionary = defs[key]
		var points: Array = d.get("lights", [])
		for p in points:
			var light := PointLight2D.new()
			light.texture = _light_texture
			light.color = InkStyle.LIGHT_WARM
			var reach := 6.5 * TILE if points.size() == 1 else 5.0 * TILE
			reach = maxf(reach, 0.62 * Vector2(room.bounds.size).length() * TILE) if points.size() == 1 else reach
			light.texture_scale = reach * 2.0 / float(_light_texture.get_width())
			light.energy = room.light_energy
			light.set_meta(&"base_energy", room.light_energy)
			light.shadow_enabled = true
			light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
			light.shadow_color = Color(0, 0, 0, 1)
			light.position = Vector2(p[0], p[1]) * TILE
			light.name = "Light_%s" % room.id
			light_root.add_child(light)
			room.lights.append(light)


func _build_switches() -> void:
	var switch_scene: PackedScene = load(LIGHT_SWITCH_SCENE_PATH)
	for room in room_list:
		if room.switch_cell.x < 0:
			continue
		var sw: LightSwitch = switch_scene.instantiate()
		sw.room = room
		sw.house = self
		sw.position = cell_to_world(room.switch_cell)
		sw.name = "Switch_%s" % room.id
		object_root.add_child(sw)
		light_switches.append(sw)


func _build_navigation() -> void:
	astar.region = Rect2i(0, 0, width, height)
	astar.cell_size = Vector2(TILE, TILE)
	astar.offset = Vector2(TILE, TILE) * 0.5
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in height:
		for x in width:
			var cell := Vector2i(x, y)
			astar.set_point_solid(cell, not _is_ghost_walkable_static(cell))


func _link_neighbors() -> void:
	for cell in doors.keys():
		var adjacent: Array[RoomData] = []
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var r := get_room_at_cell(cell + dir)
			if r and not adjacent.has(r):
				adjacent.append(r)
		for a in adjacent:
			for b in adjacent:
				if a != b and not a.neighbors.has(b):
					a.neighbors.append(b)


func _make_light_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.55, Color(1, 1, 1, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


# --- Queries ------------------------------------------------------------------

func char_at(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return " "
	return grid[cell.y][cell.x]


func _is_wall(x: int, y: int) -> bool:
	return char_at(Vector2i(x, y)) in SOLID_CHARS


func is_wall_cell(cell: Vector2i) -> bool:
	return char_at(cell) in SOLID_CHARS


func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / TILE), floori(world_position.y / TILE))


func cell_to_world(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


func get_room_at_cell(cell: Vector2i) -> RoomData:
	return _cell_room.get(cell)


func get_room_at(world_position: Vector2) -> RoomData:
	return _cell_room.get(world_to_cell(world_position))


func get_room_by_id(room_id: StringName) -> RoomData:
	for r in room_list:
		if r.id == room_id:
			return r
	return null


func indoor_rooms() -> Array[RoomData]:
	var out: Array[RoomData] = []
	for r in room_list:
		if not r.is_outdoors:
			out.append(r)
	return out


func is_indoors(world_position: Vector2) -> bool:
	var cell := world_to_cell(world_position)
	var room := get_room_at_cell(cell)
	if room:
		return not room.is_outdoors
	return doors.has(cell) and not (doors[cell] as Door).is_front_door


func is_power_on() -> bool:
	return electrical == null or electrical.is_powered()


func is_room_lit(room: RoomData) -> bool:
	if room == null or room.is_outdoors:
		return false
	return room.light_switch_on and is_power_on()


func is_point_lit(world_position: Vector2) -> bool:
	var room := get_room_at(world_position)
	if room and room.is_outdoors:
		return world_position.distance_to(yard_light_position()) < 7.0 * TILE
	return is_room_lit(room)


func yard_light_position() -> Vector2:
	var p: Array = layout.get("yard_light", [0, 0])
	return Vector2(p[0], p[1]) * TILE


func door_at(cell: Vector2i) -> Door:
	return doors.get(cell)


func set_room_light(room: RoomData, on: bool) -> void:
	room.light_switch_on = on
	refresh_lights()


func refresh_lights() -> void:
	for room in room_list:
		var lit := is_room_lit(room)
		for light in room.lights:
			light.enabled = lit
	for sw in light_switches:
		sw.queue_redraw()
	lights_changed.emit()


# --- Navigation ---------------------------------------------------------------

func _is_ghost_walkable_static(cell: Vector2i) -> bool:
	var c := char_at(cell)
	if c == "D":
		return true
	if c in "#XF O":
		return false
	return not furniture_cells.has(cell)


func is_ghost_walkable(cell: Vector2i) -> bool:
	if not astar.region.has_point(cell):
		return false
	return not astar.is_point_solid(cell)


## Blocks or unblocks a whole room for ghost navigation (safe room ward).
func set_room_blocked(room: RoomData, blocked: bool) -> void:
	if room == null:
		return
	_blocked_rooms[room.key] = blocked
	for cell in room.cells:
		if _is_ghost_walkable_static(cell):
			astar.set_point_solid(cell, blocked)


func is_room_blocked(room: RoomData) -> bool:
	return room != null and _blocked_rooms.get(room.key, false)


func find_path(from_world: Vector2, to_world: Vector2) -> PackedVector2Array:
	var from_cell := world_to_cell(from_world)
	var to_cell := world_to_cell(to_world)
	if not is_ghost_walkable(from_cell):
		from_cell = nearest_walkable_cell(from_cell)
	if not is_ghost_walkable(to_cell):
		to_cell = nearest_walkable_cell(to_cell)
	if from_cell.x < 0 or to_cell.x < 0:
		return PackedVector2Array()
	return astar.get_point_path(from_cell, to_cell)


func nearest_walkable_cell(cell: Vector2i, max_radius: int = 12) -> Vector2i:
	if is_ghost_walkable(cell):
		return cell
	for radius in range(1, max_radius + 1):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var c := cell + Vector2i(dx, dy)
				if is_ghost_walkable(c):
					var d := Vector2(dx, dy).length()
					if d < best_d:
						best_d = d
						best = c
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


func random_walkable_cell(room: RoomData, rng: RandomNumberGenerator) -> Vector2i:
	var options: Array[Vector2i] = []
	for cell in room.cells:
		if is_ghost_walkable(cell):
			options.append(cell)
	if options.is_empty():
		return Vector2i(-1, -1)
	return options[rng.randi() % options.size()]


func doors_near(world_position: Vector2, radius: float) -> Array[Door]:
	var out: Array[Door] = []
	for d in doors.values():
		var door: Door = d
		if not door.is_front_door and door.global_position.distance_to(world_position) <= radius:
			out.append(door)
	return out


func map_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(width, height) * TILE)
