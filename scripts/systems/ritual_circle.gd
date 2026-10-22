class_name RitualCircle
extends Interactable
## Minimal exorcism: a salt circle with candles. Hold E to perform the rite.
## The ghost must be near the circle, the entity must be named in the
## journal, and the ghost may interrupt. Naming the wrong entity fails the
## rite and provokes a hunt. Kept self-contained so other rituals can be
## added as sibling classes later.

signal ritual_completed(success: bool)

const RADIUS := 5.0 * InkStyle.TILE
const DURATION := 7.0
const INTERRUPT_CHECK := 1.0
const SNUFF_TIME := 5.0

var ghost: GhostController
var hunt_director: HuntDirector
var investigation: InvestigationManager
var consumed: bool = false
var lit: bool = true
var _holding: bool = false
var _interrupt_timer: float = INTERRUPT_CHECK
var _snuffed: float = 0.0
var _time: float = 0.0
var _light: PointLight2D
var _flames: Array[StatusLed] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	hold_duration = DURATION
	interaction_range = 42.0
	highlight_extent = Vector2(24, 24)
	super._ready()
	z_index = -12
	_rng.randomize()
	for i in 5:
		var a := TAU * float(i) / 5.0 - PI * 0.5
		var flame := StatusLed.new()
		flame.radius = 1.6
		flame.color = InkStyle.LIGHT_WARD
		flame.position = Vector2(cos(a), sin(a)) * 20.0
		add_child(flame)
		_flames.append(flame)
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
	_light.texture_scale = 1.2
	_light.color = InkStyle.LIGHT_WARD
	_light.energy = 0.55
	add_child(_light)


func can_interact(actor: Node) -> bool:
	return super.can_interact(actor) and not consumed


func get_prompt(_actor: Node) -> String:
	if _snuffed > 0.0:
		return "The candles are out..."
	var named := investigation.selected_ghost() if investigation else null
	if named == null:
		return "Perform the Rite (name the entity in your journal first)"
	return "Perform the Rite — banish \"%s\"" % named.display_name


func ghost_in_circle() -> bool:
	return ghost != null and ghost.is_active() and ghost.global_position.distance_to(global_position) <= RADIUS


func can_continue_hold(_actor: Node) -> bool:
	return _snuffed <= 0.0 and investigation.selected_ghost() != null and ghost_in_circle()


func get_hold_status(_actor: Node) -> String:
	if investigation.selected_ghost() == null:
		return "You do not know its name."
	if _snuffed > 0.0:
		return "The flames have died."
	if not ghost_in_circle():
		return "The circle is silent. Its presence is too far away."
	return "Its presence presses against the circle..."


func on_hold_started(_actor: Node) -> void:
	_holding = true
	_interrupt_timer = INTERRUPT_CHECK
	AudioManager.start_loop(&"ritual", &"ritual_loop", -6.0)


func on_hold_cancelled(_actor: Node) -> void:
	_stop_holding()


func _stop_holding() -> void:
	_holding = false
	if ghost:
		ghost.ritual_provocation = 0.0
	AudioManager.stop_loop(&"ritual")


func interact(actor: Node) -> void:
	_stop_holding()
	consumed = true
	var named := investigation.selected_ghost()
	var success := named != null and named.id == ghost.definition.id
	if success:
		ghost.banish()
		investigation.set_exorcism_result(&"success")
		investigation.notify("The candles flare white. Whatever lived here is gone.", &"evidence")
		investigation.add_field_note("The rite of expulsion succeeded.")
	else:
		investigation.set_exorcism_result(&"failed")
		investigation.notify("The rite fails. It knows you did not speak its true name.", &"danger")
		investigation.add_field_note("The rite failed. The entity was enraged.")
		hunt_director.cooldown = 0.0
		hunt_director.start_hunt()
	_set_lit(false)
	ritual_completed.emit(success)
	super.interact(actor)


func _set_lit(value: bool) -> void:
	lit = value
	for f in _flames:
		f.visible = value
	_light.enabled = value


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _snuffed > 0.0:
		_snuffed -= delta
		if _snuffed <= 0.0 and not consumed:
			_set_lit(true)
	if not _holding or ghost == null:
		return
	if not ghost_in_circle():
		ghost.ritual_provocation = 0.0
		return
	ghost.ritual_provocation = 1.0
	_interrupt_timer -= delta
	if _interrupt_timer > 0.0:
		return
	_interrupt_timer = INTERRUPT_CHECK
	var chance := 0.06 * ghost.definition.proximity_aggression
	if _rng.randf() < chance:
		_interrupt()


func _interrupt() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player:
		player.interaction.cancel_hold()
	_stop_holding()
	_snuffed = SNUFF_TIME
	_set_lit(false)
	AudioManager.play_at(&"knock", global_position, 4.0, 0.6)
	investigation.notify("A cold breath snuffs the candles.", &"danger")
	if player and player.sanity.value <= ghost.definition.hunt_sanity_threshold + 20.0 and _rng.randf() < 0.5:
		hunt_director.cooldown = 0.0
		hunt_director.start_hunt()
	else:
		ghost.start_manifestation()


func _draw() -> void:
	var salt := Color(InkStyle.PAPER, 0.8)
	var pts := InkStyle.jitter_points(InkStyle.ellipse_points(Vector2.ZERO, Vector2(22, 22), 28), 333, 1.0)
	pts.append(pts[0])
	draw_polyline(pts, salt, 2.6, true)
	var inner := InkStyle.jitter_points(InkStyle.ellipse_points(Vector2.ZERO, Vector2(15, 15), 22), 334, 0.8)
	inner.append(inner[0])
	draw_polyline(inner, Color(salt, 0.5), 1.0, true)
	for i in 5:
		var a := TAU * float(i) / 5.0 - PI * 0.5
		var b := TAU * float(i + 2) / 5.0 - PI * 0.5
		draw_line(Vector2(cos(a), sin(a)) * 15.0, Vector2(cos(b), sin(b)) * 15.0, Color(InkStyle.BLOOD, 0.8), 1.0)
		var c := Vector2(cos(a), sin(a)) * 20.0
		draw_circle(c, 2.4, InkStyle.PAPER_MUTED)
		draw_arc(c, 2.4, 0.0, TAU, 10, InkStyle.INK, InkStyle.DETAIL_WIDTH)
	if lit and _light:
		_light.energy = 0.5 + sin(_time * 9.0) * 0.05
