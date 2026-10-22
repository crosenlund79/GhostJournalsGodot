class_name Furniture
extends Node2D
## A piece of furniture occupying a rectangle of tiles. Creates its own
## collision and draws a procedural top-down placeholder. Drop a PNG at
## res://assets/sprites/furniture/<type>.png to replace the drawing.

const TILE := InkStyle.TILE
## Types that are walked over (floor coverings) and never collide.
const FLAT_TYPES: Array[StringName] = [&"rug", &"runner", &"bathmat"]
## Inset (pixels) of the collision box relative to the tile rectangle.
const COLLISION_INSET := 3.0

@export var furniture_type: StringName = &"boxes"

var cell_rect: Rect2i
var size_px: Vector2
var seed_value: int = 0
var _texture: Texture2D


func setup(rect: Rect2i, index: int) -> void:
	cell_rect = rect
	size_px = Vector2(rect.size) * TILE
	position = Vector2(rect.position) * TILE + size_px * 0.5
	seed_value = index * 977 + rect.position.x * 31 + rect.position.y
	name = "%s_%d" % [furniture_type, index]


func blocks_movement() -> bool:
	return not FLAT_TYPES.has(furniture_type)


func _ready() -> void:
	_texture = InkStyle.try_texture("furniture/%s" % furniture_type)
	z_index = -15 if not blocks_movement() else -5
	if blocks_movement():
		var body := StaticBody2D.new()
		body.collision_layer = House.FURNITURE_LAYER
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = size_px - Vector2.ONE * COLLISION_INSET * 2.0
		shape.shape = rs
		body.add_child(shape)
		add_child(body)


func _draw() -> void:
	var r := Rect2(-size_px * 0.5, size_px)
	if _texture:
		draw_texture_rect(_texture, r, false)
		return
	var inner := r.grow(-3.0)
	var s := seed_value
	match furniture_type:
		&"bed":
			InkStyle.draw_box(self, inner, InkStyle.fill(&"wood"), s)
			var mattress := inner.grow(-3.0)
			InkStyle.draw_box(self, mattress, InkStyle.fill(&"linen"), s + 1)
			var pillow_h := 12.0
			var pw := (mattress.size.x - 9.0) * 0.5
			InkStyle.draw_box(self, Rect2(mattress.position + Vector2(3, 3), Vector2(pw, pillow_h)), InkStyle.PAPER, s + 2, InkStyle.DETAIL_WIDTH)
			InkStyle.draw_box(self, Rect2(mattress.position + Vector2(6 + pw, 3), Vector2(pw, pillow_h)), InkStyle.PAPER, s + 3, InkStyle.DETAIL_WIDTH)
			var fold := mattress.position.y + mattress.size.y * 0.42
			InkStyle.draw_box(self, Rect2(Vector2(mattress.position.x, fold), Vector2(mattress.size.x, mattress.end.y - fold)), InkStyle.fill(&"fabric_red"), s + 4, InkStyle.DETAIL_WIDTH)
			InkStyle.draw_detail(self, Vector2(mattress.position.x + 6, fold + 10), Vector2(mattress.end.x - 10, fold + 18), s + 5)
		&"nightstand", &"side_table", &"dresser", &"cabinet":
			InkStyle.draw_box(self, inner, InkStyle.fill(&"wood"), s)
			InkStyle.draw_detail_rect(self, inner.grow(-4.0), s + 1)
			if furniture_type == &"nightstand":
				InkStyle.draw_oval(self, inner.get_center(), Vector2(5, 5), InkStyle.PAPER_MUTED, s + 2, InkStyle.DETAIL_WIDTH)
		&"wardrobe", &"bookshelf", &"shelf":
			InkStyle.draw_box(self, inner, InkStyle.fill(&"wood").darkened(0.1), s)
			var vertical := inner.size.y > inner.size.x
			var n := int(maxf(inner.size.x, inner.size.y) / 10.0)
			for i in range(1, n):
				var k := float(i) / float(n)
				if vertical:
					var y := inner.position.y + inner.size.y * k
					InkStyle.draw_detail(self, Vector2(inner.position.x + 2, y), Vector2(inner.end.x - 2, y), s + i)
				else:
					var x := inner.position.x + inner.size.x * k
					InkStyle.draw_detail(self, Vector2(x, inner.position.y + 2), Vector2(x, inner.end.y - 2), s + i)
		&"bathtub":
			InkStyle.draw_box(self, inner, InkStyle.fill(&"porcelain"), s)
			InkStyle.draw_oval(self, inner.get_center(), inner.size * 0.5 - Vector2(5, 5), InkStyle.fill(&"porcelain").darkened(0.18), s + 1, InkStyle.DETAIL_WIDTH)
			draw_circle(inner.get_center() + Vector2(0, inner.size.y * 0.32), 2.0, InkStyle.INK)
		&"toilet":
			InkStyle.draw_box(self, Rect2(inner.position, Vector2(inner.size.x, 8)), InkStyle.fill(&"porcelain"), s)
			InkStyle.draw_oval(self, inner.get_center() + Vector2(0, 4), Vector2(9, 10), InkStyle.fill(&"porcelain"), s + 1)
			InkStyle.draw_oval(self, inner.get_center() + Vector2(0, 5), Vector2(5, 6), InkStyle.fill(&"porcelain").darkened(0.25), s + 2, InkStyle.DETAIL_WIDTH)
		&"bath_sink", &"sink":
			InkStyle.draw_box(self, inner, InkStyle.fill(&"porcelain") if furniture_type == &"bath_sink" else InkStyle.fill(&"metal"), s)
			InkStyle.draw_oval(self, inner.get_center(), Vector2(8, 7), InkStyle.fill(&"porcelain").darkened(0.2), s + 1, InkStyle.DETAIL_WIDTH)
			draw_circle(inner.get_center(), 1.5, InkStyle.INK)
		&"bathmat":
			InkStyle.draw_box(self, inner, InkStyle.SICK_GREEN.darkened(0.2), s, InkStyle.DETAIL_WIDTH)
		&"washer":
			InkStyle.draw_box(self, inner, InkStyle.fill(&"porcelain").darkened(0.1), s)
			InkStyle.draw_oval(self, inner.get_center() + Vector2(0, 2), Vector2(8, 8), InkStyle.fill(&"metal"), s + 1, InkStyle.DETAIL_WIDTH)
			InkStyle.draw_detail(self, inner.position + Vector2(3, 5), Vector2(inner.end.x - 3, inner.position.y + 5), s + 2)
		&"water_heater":
			InkStyle.draw_oval(self, Vector2.ZERO, inner.size * 0.5, InkStyle.fill(&"metal"), s)
			InkStyle.draw_oval(self, Vector2.ZERO, inner.size * 0.25, InkStyle.fill(&"metal").darkened(0.2), s + 1, InkStyle.DETAIL_WIDTH)
		&"boxes":
			InkStyle.draw_box(self, inner, InkStyle.fill(&"cardboard"), s)
			InkStyle.draw_detail(self, Vector2(0, inner.position.y + 2), Vector2(0, inner.end.y - 2), s + 1)
			if inner.size.y > TILE:
				InkStyle.draw_detail(self, Vector2(inner.position.x + 2, 0), Vector2(inner.end.x - 2, 0), s + 2)
		&"plant":
			InkStyle.draw_oval(self, Vector2.ZERO, Vector2(8, 8), InkStyle.fill(&"cardboard").darkened(0.3), s)
			for i in 5:
				var a := TAU * float(i) / 5.0 + float(s % 10) * 0.3
				InkStyle.draw_oval(self, Vector2(cos(a), sin(a)) * 7.0, Vector2(6, 4), InkStyle.fill(&"plant"), s + i, InkStyle.DETAIL_WIDTH)
		&"coat_rack":
			InkStyle.draw_oval(self, Vector2.ZERO, Vector2(9, 9), InkStyle.fill(&"wood"), s)
			InkStyle.draw_oval(self, Vector2(4, -2), Vector2(7, 5), InkStyle.fill(&"fabric"), s + 1, InkStyle.DETAIL_WIDTH)
		&"tv_stand":
			InkStyle.draw_box(self, inner, InkStyle.fill(&"wood"), s)
			InkStyle.draw_box(self, Rect2(inner.position + Vector2(inner.size.x * 0.2, 2), Vector2(inner.size.x * 0.6, 6)), InkStyle.INK.lightened(0.15), s + 1, InkStyle.DETAIL_WIDTH)
		&"rug", &"runner":
			var col := InkStyle.fill(&"fabric_red").darkened(0.15) if furniture_type == &"rug" else InkStyle.fill(&"fabric").darkened(0.1)
			InkStyle.draw_box(self, inner, col, s, InkStyle.DETAIL_WIDTH)
			InkStyle.draw_detail_rect(self, inner.grow(-6.0), s + 1, InkStyle.INK_FADED)
		&"coffee_table", &"kitchen_table":
			InkStyle.draw_box(self, inner, InkStyle.fill(&"pale_wood"), s)
			InkStyle.draw_detail(self, inner.position + Vector2(4, inner.size.y * 0.5), inner.end - Vector2(4, inner.size.y * 0.5), s + 1)
		&"sofa", &"armchair":
			InkStyle.draw_box(self, inner, InkStyle.fill(&"fabric"), s)
			var back := Rect2(Vector2(inner.position.x, inner.end.y - 9), Vector2(inner.size.x, 9))
			InkStyle.draw_box(self, back, InkStyle.fill(&"fabric").darkened(0.2), s + 1, InkStyle.DETAIL_WIDTH)
			InkStyle.draw_box(self, Rect2(inner.position, Vector2(7, inner.size.y - 9)), InkStyle.fill(&"fabric").darkened(0.12), s + 2, InkStyle.DETAIL_WIDTH)
			InkStyle.draw_box(self, Rect2(Vector2(inner.end.x - 7, inner.position.y), Vector2(7, inner.size.y - 9)), InkStyle.fill(&"fabric").darkened(0.12), s + 3, InkStyle.DETAIL_WIDTH)
			if furniture_type == &"sofa":
				var midx := inner.get_center().x
				InkStyle.draw_detail(self, Vector2(midx, inner.position.y + 3), Vector2(midx, inner.end.y - 10), s + 4)
		&"fireplace":
			InkStyle.draw_box(self, inner, InkStyle.fill(&"stone"), s)
			InkStyle.draw_box(self, Rect2(inner.position + Vector2(inner.size.x * 0.25, inner.size.y * 0.35), Vector2(inner.size.x * 0.5, inner.size.y * 0.65 - 1)), InkStyle.PAPER_DEEP, s + 1, InkStyle.DETAIL_WIDTH)
		&"dining_table", &"island":
			InkStyle.draw_box(self, inner, InkStyle.fill(&"wood") if furniture_type == &"dining_table" else InkStyle.fill(&"pale_wood"), s)
			InkStyle.draw_detail_rect(self, inner.grow(-5.0), s + 1, InkStyle.INK_FADED)
			if furniture_type == &"dining_table":
				InkStyle.draw_oval(self, Vector2(-14, 0), Vector2(5, 5), InkStyle.PAPER_MUTED, s + 2, InkStyle.DETAIL_WIDTH)
				InkStyle.draw_oval(self, Vector2(16, 2), Vector2(5, 5), InkStyle.PAPER_MUTED, s + 3, InkStyle.DETAIL_WIDTH)
		&"chair":
			InkStyle.draw_box(self, r.grow(-8.0), InkStyle.fill(&"wood"), s)
			InkStyle.draw_detail(self, Vector2(-7, -9), Vector2(7, -9), s + 1)
		&"counter":
			InkStyle.draw_box(self, inner, InkStyle.fill(&"pale_wood").darkened(0.1), s)
			InkStyle.draw_detail(self, Vector2(inner.position.x + 2, inner.end.y - 6), Vector2(inner.end.x - 2, inner.end.y - 6), s + 1)
		&"stove":
			InkStyle.draw_box(self, inner, InkStyle.fill(&"metal").darkened(0.2), s)
			for o in [Vector2(-6, -6), Vector2(6, -6), Vector2(-6, 6), Vector2(6, 6)]:
				InkStyle.draw_oval(self, o, Vector2(4, 4), InkStyle.INK.lightened(0.1), s + int(o.x), InkStyle.DETAIL_WIDTH)
		&"fridge":
			InkStyle.draw_box(self, inner, InkStyle.fill(&"porcelain"), s)
			InkStyle.draw_detail(self, Vector2(inner.position.x + 2, 0), Vector2(inner.end.x - 2, 0), s + 1)
		&"trash":
			InkStyle.draw_oval(self, Vector2.ZERO, Vector2(9, 9), InkStyle.fill(&"metal").darkened(0.1), s)
			InkStyle.draw_oval(self, Vector2.ZERO, Vector2(5, 5), InkStyle.INK.lightened(0.15), s + 1, InkStyle.DETAIL_WIDTH)
		&"van":
			InkStyle.draw_box(self, inner, InkStyle.fill(&"vehicle"), s)
			var cab := Rect2(Vector2(inner.end.x - 30, inner.position.y + 3), Vector2(27, inner.size.y - 6))
			InkStyle.draw_box(self, cab, InkStyle.fill(&"vehicle").darkened(0.2), s + 1, InkStyle.DETAIL_WIDTH)
			InkStyle.draw_box(self, Rect2(cab.position + Vector2(12, 4), Vector2(10, cab.size.y - 8)), InkStyle.INK.lightened(0.1), s + 2, InkStyle.DETAIL_WIDTH)
			for i in 4:
				var x := inner.position.x + 14.0 + i * 30.0
				InkStyle.draw_detail(self, Vector2(x, inner.position.y + 4), Vector2(x, inner.end.y - 4), s + 3 + i, InkStyle.INK_FADED)
		&"rack":
			InkStyle.draw_box(self, inner, InkStyle.fill(&"metal").darkened(0.25), s)
			InkStyle.draw_detail(self, Vector2(inner.position.x + 2, 0), Vector2(inner.end.x - 2, 0), s + 1, InkStyle.INK_FADED)
		&"tree":
			InkStyle.draw_oval(self, Vector2.ZERO, r.size * 0.5, InkStyle.fill(&"plant").darkened(0.25), s)
			InkStyle.draw_oval(self, Vector2(-6, -4), r.size * 0.3, InkStyle.fill(&"plant").darkened(0.05), s + 1, InkStyle.DETAIL_WIDTH)
			for i in 6:
				var a := TAU * float(i) / 6.0
				InkStyle.draw_detail(self, Vector2.ZERO, Vector2(cos(a), sin(a)) * r.size.x * 0.32, s + 2 + i, InkStyle.INK_FADED)
		&"bush":
			InkStyle.draw_oval(self, Vector2.ZERO, r.size * 0.42, InkStyle.fill(&"plant").darkened(0.15), s)
		_:
			InkStyle.draw_box(self, inner, InkStyle.fill(&"wood"), s)
