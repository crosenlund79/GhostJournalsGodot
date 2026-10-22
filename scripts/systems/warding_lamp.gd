class_name WardingLamp
extends Interactable
## The blessed object of the safe room. Purely feedback: shows whether the
## room's protection is active and explains it when examined.

signal examined(text: String)

var lit: bool = false
var _light: PointLight2D
var _glow: StatusLed
var _time: float = 0.0


func _ready() -> void:
	prompt_text = "Examine the Warding Lamp"
	highlight_extent = Vector2(12, 12)
	super._ready()
	z_index = -4
	_light = PointLight2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	_light.texture = tex
	_light.texture_scale = 1.6
	_light.color = InkStyle.LIGHT_WARD
	_light.energy = 0.9
	_light.shadow_enabled = true
	add_child(_light)
	_glow = StatusLed.new()
	_glow.radius = 2.5
	_glow.color = InkStyle.LIGHT_WARD
	add_child(_glow)
	set_lit(lit)


func set_lit(value: bool) -> void:
	lit = value
	if _light:
		_light.enabled = lit
		_glow.visible = lit
	queue_redraw()


func interact(actor: Node) -> void:
	var text := "The warding lamp burns steadily. Nothing unholy can cross into this room while it is lit." if lit \
		else "The warding lamp is dark. Without power, this room offers no protection."
	examined.emit(text)
	super.interact(actor)


func _process(delta: float) -> void:
	_time += delta
	if lit and _light:
		_light.energy = 0.85 + sin(_time * 7.0) * 0.05 + sin(_time * 13.0) * 0.04


func _draw() -> void:
	# Small altar table with a lamp and two candles, seen from above.
	InkStyle.draw_box(self, Rect2(Vector2(-12, -9), Vector2(24, 18)), InkStyle.fill(&"wood").darkened(0.2), 9001)
	InkStyle.draw_detail_rect(self, Rect2(Vector2(-9, -6), Vector2(18, 12)), 9002, InkStyle.INK_FADED)
	InkStyle.draw_oval(self, Vector2.ZERO, Vector2(5, 5), InkStyle.PAPER_MUTED if lit else InkStyle.PAPER_DARK, 9003, InkStyle.DETAIL_WIDTH)
	for x in [-8.0, 8.0]:
		draw_circle(Vector2(x, 4), 2.2, InkStyle.PAPER)
		draw_circle(Vector2(x, 4), 2.2, InkStyle.INK, false, InkStyle.DETAIL_WIDTH)
	# Cross carved into the table.
	InkStyle.draw_detail(self, Vector2(0, -8), Vector2(0, -3), 9004)
	InkStyle.draw_detail(self, Vector2(-2.5, -6.5), Vector2(2.5, -6.5), 9005)
