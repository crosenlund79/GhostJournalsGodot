class_name InkStyle
extends RefCounted
## Central visual configuration for the "Dirty Ink Horror" placeholder art.
##
## Every procedural drawing in the project pulls its colours and stroke widths
## from here, so the whole look can be tuned in one place. Any visual that has a
## hand-drawn replacement PNG under res://assets/sprites/ uses that texture
## instead (see [method try_texture]).

const TILE: int = 32

## Strict line system: one weight for outer contours, one for interior detail.
const OUTLINE_WIDTH: float = 2.4
const DETAIL_WIDTH: float = 1.2
## Maximum per-vertex wobble that gives the "handmade" imperfection.
const JITTER: float = 0.8

const INK := Color(0.07, 0.062, 0.055)
const INK_FADED := Color(0.07, 0.062, 0.055, 0.55)
const PAPER := Color(0.82, 0.78, 0.68)
const PAPER_MUTED := Color(0.62, 0.58, 0.50)
const PAPER_DARK := Color(0.15, 0.135, 0.115)
const PAPER_DEEP := Color(0.09, 0.08, 0.07)
const RUST := Color(0.52, 0.20, 0.14)
const BLOOD := Color(0.42, 0.08, 0.07)
const SICK_GREEN := Color(0.46, 0.52, 0.36)

const WALL_FILL := Color(0.17, 0.16, 0.15)
const WALL_HATCH := Color(0.11, 0.10, 0.095)
const VOID_FILL := Color(0.06, 0.065, 0.06)
const GRASS := Color(0.20, 0.23, 0.17)
const FENCE := Color(0.30, 0.25, 0.19)

const LIGHT_WARM := Color(1.0, 0.86, 0.66)
const LIGHT_FLASH := Color(1.0, 0.95, 0.82)
const LIGHT_UV := Color(0.55, 0.32, 1.0)
const LIGHT_WARD := Color(1.0, 0.70, 0.40)
const UV_PRINT := Color(0.72, 1.0, 0.55)
const NIGHT_VISION := Color(0.42, 0.62, 0.45)
const ORB := Color(0.85, 1.0, 0.85)
const GHOST_BODY := Color(0.05, 0.05, 0.065)
const GHOST_RIM := Color(0.40, 0.42, 0.48)
const GHOST_FACE := Color(0.78, 0.76, 0.70)

## Darkness of the world when no light reaches a surface.
const DARKNESS := Color(0.055, 0.055, 0.07)

const FLOOR_COLORS := {
	&"wood": Color(0.40, 0.31, 0.23),
	&"dark_wood": Color(0.31, 0.24, 0.18),
	&"tile": Color(0.50, 0.50, 0.45),
	&"checker": Color(0.47, 0.45, 0.40),
	&"concrete": Color(0.38, 0.37, 0.34),
	&"carpet": Color(0.36, 0.26, 0.26),
	&"grass": GRASS,
}

const FURNITURE_FILL := {
	&"wood": Color(0.36, 0.26, 0.18),
	&"pale_wood": Color(0.50, 0.40, 0.29),
	&"fabric": Color(0.33, 0.30, 0.27),
	&"fabric_red": Color(0.38, 0.22, 0.20),
	&"linen": Color(0.66, 0.63, 0.56),
	&"metal": Color(0.45, 0.46, 0.45),
	&"porcelain": Color(0.72, 0.72, 0.68),
	&"cardboard": Color(0.50, 0.40, 0.27),
	&"plant": Color(0.24, 0.31, 0.21),
	&"stone": Color(0.42, 0.41, 0.38),
	&"vehicle": Color(0.33, 0.35, 0.33),
}


static func fill(key: StringName) -> Color:
	return FURNITURE_FILL.get(key, FURNITURE_FILL[&"wood"])


static func floor_color(key: StringName) -> Color:
	return FLOOR_COLORS.get(key, FLOOR_COLORS[&"wood"])


## Loads a hand-drawn replacement sprite if one exists, e.g.
## `try_texture("furniture/bed")` -> res://assets/sprites/furniture/bed.png.
static func try_texture(relative_path: String) -> Texture2D:
	var path := "res://assets/sprites/%s.png" % relative_path
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


static func jitter_points(points: PackedVector2Array, seed_value: int, amount: float = JITTER) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedVector2Array()
	for p in points:
		out.append(p + Vector2(rng.randf_range(-amount, amount), rng.randf_range(-amount, amount)))
	return out


static func rect_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])


static func ellipse_points(center: Vector2, radius: Vector2, segments: int = 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return pts


## Filled polygon with a single consistent outer contour.
static func draw_shape(ci: CanvasItem, points: PackedVector2Array, fill_color: Color, seed_value: int,
		outline: Color = INK, width: float = OUTLINE_WIDTH) -> void:
	var pts := jitter_points(points, seed_value)
	if fill_color.a > 0.0:
		ci.draw_colored_polygon(pts, fill_color)
	if width > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, outline, width, true)


static func draw_box(ci: CanvasItem, rect: Rect2, fill_color: Color, seed_value: int,
		width: float = OUTLINE_WIDTH, outline: Color = INK) -> void:
	draw_shape(ci, rect_points(rect), fill_color, seed_value, outline, width)


static func draw_oval(ci: CanvasItem, center: Vector2, radius: Vector2, fill_color: Color, seed_value: int,
		width: float = OUTLINE_WIDTH, outline: Color = INK) -> void:
	var segments := clampi(int(maxf(radius.x, radius.y) * 0.9), 10, 28)
	draw_shape(ci, ellipse_points(center, radius, segments), fill_color, seed_value, outline, width)


## Interior detail stroke (thinner, same ink).
static func draw_detail(ci: CanvasItem, a: Vector2, b: Vector2, seed_value: int,
		color: Color = INK, width: float = DETAIL_WIDTH) -> void:
	var pts := jitter_points(PackedVector2Array([a, (a + b) * 0.5, b]), seed_value, JITTER * 0.6)
	ci.draw_polyline(pts, color, width, true)


static func draw_detail_rect(ci: CanvasItem, rect: Rect2, seed_value: int, color: Color = INK) -> void:
	var pts := jitter_points(rect_points(rect), seed_value, JITTER * 0.6)
	pts.append(pts[0])
	ci.draw_polyline(pts, color, DETAIL_WIDTH, true)


## Texture that shaded canvas items can use to ignore scene lighting (UI-like
## world markers, ghost visuals that must not be lit by lamps, etc.).
static func unshaded_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return mat
