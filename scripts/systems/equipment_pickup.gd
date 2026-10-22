class_name EquipmentPickup
extends Interactable
## A piece of equipment lying in the world (on the van rack or dropped).
## Taking it with a full inventory swaps it with the held item.

signal taken(pickup: EquipmentPickup)

var definition: EquipmentDefinition
var _texture: Texture2D


func _ready() -> void:
	highlight_extent = Vector2(9, 9)
	interaction_range = 40.0
	super._ready()
	z_index = -2
	if definition:
		_texture = InkStyle.try_texture("equipment/%s" % definition.id)


func get_prompt(actor: Node) -> String:
	var player := actor as Player
	if definition == null:
		return ""
	if player and not player.equipment.has_free_slot() and player.equipment.get_current() == null:
		return "Take %s" % definition.display_name
	if player and not player.equipment.has_free_slot():
		return "Swap for %s" % definition.display_name
	return "Take %s" % definition.display_name


func interact(actor: Node) -> void:
	var player := actor as Player
	if player == null or definition == null:
		return
	var swapped: EquipmentDefinition = null
	if not player.equipment.has_free_slot():
		swapped = player.equipment.remove_selected()
	player.equipment.add_item(definition)
	AudioManager.play(&"click", -4.0, 0.7)
	if swapped:
		definition = swapped
		_texture = InkStyle.try_texture("equipment/%s" % definition.id)
		queue_redraw()
	else:
		taken.emit(self)
		queue_free()
	super.interact(actor)


func _draw() -> void:
	if _texture:
		draw_texture(_texture, -_texture.get_size() * 0.5)
		return
	var base := Rect2(Vector2(-7, -5), Vector2(14, 10))
	var col := InkStyle.fill(&"metal")
	match definition.id if definition else &"":
		&"flashlight":
			col = InkStyle.fill(&"metal").darkened(0.2)
		&"uv_flashlight":
			col = InkStyle.LIGHT_UV.darkened(0.55)
		&"emf_reader":
			col = InkStyle.PAPER_DARK
		&"spirit_box":
			col = InkStyle.RUST.darkened(0.3)
		&"video_camera":
			col = InkStyle.INK.lightened(0.2)
		&"thermometer":
			col = InkStyle.PAPER_MUTED
		&"ritual_kit":
			col = InkStyle.PAPER
	InkStyle.draw_box(self, base, col, hash(definition.id) if definition else 0)
	if definition:
		draw_string(ThemeDB.fallback_font, Vector2(-6, 3), definition.short_name.substr(0, 3), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, InkStyle.INK if col.get_luminance() > 0.4 else InkStyle.PAPER)
