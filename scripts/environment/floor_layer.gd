extends Node2D
## Draws all floor surfaces of a [House] procedurally (planks, tiles,
## concrete, carpet, yard grass). Purely presentational.

const TILE := InkStyle.TILE

var house: House


func _draw() -> void:
	if house == null:
		return
	for y in house.height:
		for x in house.width:
			var cell := Vector2i(x, y)
			var c := house.char_at(cell)
			var rect := Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE))
			if c == " ":
				draw_rect(rect, InkStyle.VOID_FILL)
			elif c == "X":
				draw_rect(rect, InkStyle.GRASS.darkened(0.25))
			elif c in "DF":
				draw_rect(rect, InkStyle.floor_color(&"dark_wood").darkened(0.2))
			elif c != "#":
				var room := house.get_room_at_cell(cell)
				_draw_floor_cell(rect, room.floor_type if room else &"wood", cell)
	# Rooms get a faint ink border where floor meets wall for readability.
	for room in house.room_list:
		if room.is_outdoors:
			_draw_yard_details(room)


func _hash(cell: Vector2i, salt: int = 0) -> int:
	return absi((cell.x * 73856093) ^ (cell.y * 19349663) ^ (salt * 83492791))


func _draw_floor_cell(rect: Rect2, floor_type: StringName, cell: Vector2i) -> void:
	var base := InkStyle.floor_color(floor_type)
	var h := _hash(cell)
	var tint := float(h % 7) / 7.0 * 0.05 - 0.025
	draw_rect(rect, base.lightened(tint) if tint > 0.0 else base.darkened(-tint))
	var line := InkStyle.INK_FADED
	match floor_type:
		&"wood", &"dark_wood":
			# Planks run horizontally; staggered seams per row.
			for i in 3:
				var yy := rect.position.y + (i + 1) * TILE / 3.0
				if i < 2:
					draw_line(Vector2(rect.position.x, yy), Vector2(rect.end.x, yy), line, InkStyle.DETAIL_WIDTH * 0.8)
			var seam := rect.position.x + float((h >> 3) % TILE)
			var row := (h >> 8) % 3
			var sy := rect.position.y + row * TILE / 3.0
			draw_line(Vector2(seam, sy), Vector2(seam, sy + TILE / 3.0), line, InkStyle.DETAIL_WIDTH * 0.8)
		&"tile":
			draw_rect(Rect2(rect.position, Vector2(TILE, TILE)), line, false, InkStyle.DETAIL_WIDTH * 0.8)
			draw_line(rect.get_center() - Vector2(TILE / 2.0, 0), rect.get_center() + Vector2(TILE / 2.0, 0), line, 0.6)
			draw_line(rect.get_center() - Vector2(0, TILE / 2.0), rect.get_center() + Vector2(0, TILE / 2.0), line, 0.6)
		&"checker":
			var half := TILE / 2.0
			for iy in 2:
				for ix in 2:
					if (ix + iy) % 2 == 0:
						draw_rect(Rect2(rect.position + Vector2(ix * half, iy * half), Vector2(half, half)), base.darkened(0.25))
		&"concrete":
			if h % 5 == 0:
				var a := rect.position + Vector2(float(h % 20) + 4.0, float((h >> 4) % 20) + 4.0)
				draw_line(a, a + Vector2(9, 4), line, InkStyle.DETAIL_WIDTH * 0.8)
				draw_line(a + Vector2(9, 4), a + Vector2(13, 11), line, InkStyle.DETAIL_WIDTH * 0.8)
			if h % 3 == 0:
				draw_circle(rect.position + Vector2(float((h >> 2) % 28) + 2.0, float((h >> 6) % 28) + 2.0), 1.4, base.darkened(0.3))
		&"carpet":
			for i in 4:
				var p := rect.position + Vector2(float((h >> (i * 3)) % 30) + 1.0, float((h >> (i * 2 + 5)) % 30) + 1.0)
				draw_circle(p, 0.9, base.darkened(0.25))
		&"grass":
			for i in 3:
				var p := rect.position + Vector2(float((h >> (i * 4)) % 28) + 2.0, float((h >> (i * 3 + 7)) % 28) + 2.0)
				draw_line(p, p + Vector2(-1.5, -4), InkStyle.GRASS.darkened(0.35), 1.0)
				draw_line(p, p + Vector2(1.5, -3.5), InkStyle.GRASS.darkened(0.35), 1.0)


func _draw_yard_details(room: RoomData) -> void:
	# Stone path from the front door to the van.
	if house.front_door == null:
		return
	var door_cell := house.front_door.cell
	var stones := 0
	for i in range(1, 4):
		var c := door_cell + Vector2i(0, i)
		var center := house.cell_to_world(c)
		InkStyle.draw_oval(self, center + Vector2(-6, 0), Vector2(7, 5), InkStyle.fill(&"stone"), stones, InkStyle.DETAIL_WIDTH)
		InkStyle.draw_oval(self, center + Vector2(7, 6), Vector2(6, 4.5), InkStyle.fill(&"stone"), stones + 50, InkStyle.DETAIL_WIDTH)
		stones += 1
