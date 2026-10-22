class_name Flashlight
extends Equipment
## Directional light beam following the player's facing. Real Light2D with
## shadows; darkness outside the beam stays dark.

@export var beam_range: float = 270.0
@export var half_angle: float = deg_to_rad(27.0)
@export var beam_color: Color = InkStyle.LIGHT_FLASH
@export var beam_energy: float = 1.15

static var _cone_cache: Dictionary = {}

var light: PointLight2D


func _ready() -> void:
	super._ready()
	light = PointLight2D.new()
	light.texture = cone_texture(half_angle)
	light.texture_scale = beam_range / 128.0
	light.color = beam_color
	light.energy = beam_energy
	light.shadow_enabled = true
	light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	light.enabled = false
	light.position = Vector2(4, 0)
	add_child(light)


func _on_activated() -> void:
	light.enabled = true


func _on_deactivated() -> void:
	light.enabled = false


## True if a world point is inside the lit beam (range, angle, no walls).
func illuminates(point: Vector2) -> bool:
	if not active:
		return false
	var origin := global_position
	var to := point - origin
	var dist := to.length()
	if dist > beam_range * 0.95:
		return false
	var forward := Vector2.RIGHT.rotated(global_rotation)
	if dist > 6.0 and absf(forward.angle_to(to)) > half_angle:
		return false
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(origin, point, 1)
	return space.intersect_ray(query).is_empty()


## Cone-shaped light texture: apex at the centre, pointing +X. 256 px wide
## so the beam reaches 128 px at scale 1.
static func cone_texture(angle: float) -> Texture2D:
	var key := snappedf(angle, 0.001)
	if _cone_cache.has(key):
		return _cone_cache[key]
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var v := Vector2(x + 0.5, y + 0.5) - c
			var d := v.length() / (size * 0.5)
			var a := 0.0
			if v.x > 0.0 and d < 1.0:
				var ang := absf(atan2(v.y, v.x))
				var cone := 1.0 - smoothstep(angle * 0.55, angle, ang)
				var falloff := pow(1.0 - d, 0.7)
				a = cone * falloff
			# Small spill glow around the lens.
			a = maxf(a, clampf(1.0 - d * 9.0, 0.0, 1.0) * 0.6)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex := ImageTexture.create_from_image(img)
	_cone_cache[key] = tex
	return tex


static func clear_cache() -> void:
	_cone_cache.clear()


func get_hud_reading() -> String:
	return "beam on" if active else "off"


func _draw_placeholder() -> void:
	InkStyle.draw_box(self, Rect2(Vector2(-4, -2.5), Vector2(10, 5)), InkStyle.fill(&"metal").darkened(0.2), 11, InkStyle.DETAIL_WIDTH)
	InkStyle.draw_box(self, Rect2(Vector2(5, -3.5), Vector2(3, 7)), InkStyle.fill(&"metal"), 12, InkStyle.DETAIL_WIDTH)
