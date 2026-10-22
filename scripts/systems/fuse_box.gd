class_name FuseBox
extends Interactable
## Wall-mounted breaker for the house. Short hold to throw the main switch.

var electrical: ElectricalSystem
var _texture: Texture2D
var _led: StatusLed


func _ready() -> void:
	hold_duration = 0.6
	interaction_range = 48.0
	highlight_extent = Vector2(12, 10)
	super._ready()
	z_index = 12
	_texture = InkStyle.try_texture("environment/fuse_box")
	_led = StatusLed.new()
	_led.position = Vector2(5, -2)
	add_child(_led)
	if electrical:
		electrical.power_changed.connect(func(_on: bool, _r: String) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	var on := electrical != null and electrical.is_powered()
	_led.color = InkStyle.SICK_GREEN.lightened(0.35) if on else InkStyle.BLOOD.lightened(0.25)
	_led.queue_redraw()
	queue_redraw()


func get_prompt(_actor: Node) -> String:
	if electrical == null:
		return ""
	return "Cut the Power" if electrical.is_powered() else "Restore Power"


func interact(actor: Node) -> void:
	AudioManager.play_at(&"switch", global_position)
	electrical.toggle("player")
	super.interact(actor)


func _draw() -> void:
	var box := Rect2(Vector2(-11, -9), Vector2(22, 18))
	if _texture:
		draw_texture_rect(_texture, box, false)
		return
	InkStyle.draw_box(self, box, InkStyle.fill(&"metal").darkened(0.35), 4242)
	InkStyle.draw_detail_rect(self, box.grow(-3.0), 4243)
	var on := electrical != null and electrical.is_powered()
	# Lever: up = on.
	var lever_y := -4.0 if on else 3.0
	draw_line(Vector2(-4, 0), Vector2(-4, lever_y), InkStyle.INK, InkStyle.OUTLINE_WIDTH)
	draw_circle(Vector2(-4, lever_y), 2.4, InkStyle.PAPER_MUTED)
