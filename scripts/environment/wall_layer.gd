extends Node2D
## Draws wall masses and the yard fence with a single consistent ink contour
## along every edge where a wall meets a walkable surface.

const TILE := InkStyle.TILE

var house: House


func _vertex_jitter(v: Vector2i) -> Vector2:
	var h := absi((v.x * 92837111) ^ (v.y * 689287499))
	return Vector2(float(h % 100) / 100.0 - 0.5, float((h >> 7) % 100) / 100.0 - 0.5) * InkStyle.JITTER * 1.6


func _p(v: Vector2i) -> Vector2:
	return Vector2(v) * TILE + _vertex_jitter(v)


func _draw() -> void:
	if house == null:
		return
	for y in house.height:
		for x in house.width:
			var cell := Vector2i(x, y)
			var c := house.char_at(cell)
			if c == "#":
				_draw_wall_cell(cell)
			elif c == "X":
				_draw_fence_cell(cell)


func _is_open(cell: Vector2i) -> bool:
	var c := house.char_at(cell)
	return not (c in "#X ")


func _draw_wall_cell(cell: Vector2i) -> void:
	var rect := Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE))
	draw_rect(rect, InkStyle.WALL_FILL)
	# Sparse diagonal hatching keeps wall masses readable but not noisy.
	if (cell.x + cell.y) % 2 == 0:
		draw_line(rect.position + Vector2(6, TILE - 6), rect.position + Vector2(TILE - 6, 6), InkStyle.WALL_HATCH, InkStyle.DETAIL_WIDTH)
	var tl := cell
	var tr := cell + Vector2i(1, 0)
	var br := cell + Vector2i(1, 1)
	var bl := cell + Vector2i(0, 1)
	var w := InkStyle.OUTLINE_WIDTH
	if _is_open(cell + Vector2i.UP):
		draw_line(_p(tl), _p(tr), InkStyle.INK, w, true)
	if _is_open(cell + Vector2i.DOWN):
		draw_line(_p(bl), _p(br), InkStyle.INK, w, true)
	if _is_open(cell + Vector2i.LEFT):
		draw_line(_p(tl), _p(bl), InkStyle.INK, w, true)
	if _is_open(cell + Vector2i.RIGHT):
		draw_line(_p(tr), _p(br), InkStyle.INK, w, true)


func _draw_fence_cell(cell: Vector2i) -> void:
	var rect := Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE))
	var horizontal := house.char_at(cell + Vector2i.LEFT) == "X" or house.char_at(cell + Vector2i.RIGHT) == "X"
	var vertical := house.char_at(cell + Vector2i.UP) == "X" or house.char_at(cell + Vector2i.DOWN) == "X"
	var c := rect.get_center()
	if horizontal:
		InkStyle.draw_box(self, Rect2(rect.position + Vector2(0, TILE * 0.38), Vector2(TILE, TILE * 0.24)), InkStyle.FENCE, cell.x * 7 + cell.y, InkStyle.DETAIL_WIDTH)
	if vertical:
		InkStyle.draw_box(self, Rect2(rect.position + Vector2(TILE * 0.38, 0), Vector2(TILE * 0.24, TILE)), InkStyle.FENCE, cell.x * 11 + cell.y, InkStyle.DETAIL_WIDTH)
	InkStyle.draw_box(self, Rect2(c - Vector2(5, 5), Vector2(10, 10)), InkStyle.FENCE.darkened(0.2), cell.x * 13 + cell.y * 3)
