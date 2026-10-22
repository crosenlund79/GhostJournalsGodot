class_name WritingBook
extends Interactable
## An old notebook lying in a room. Ghosts with "Demonic Writing" evidence may
## scrawl in it; the player examines it with E.

var room: RoomData
var written: bool = false
var _seed: int = 0


func _ready() -> void:
	prompt_text = "Examine Notebook"
	highlight_extent = Vector2(9, 7)
	interaction_range = 40.0
	super._ready()
	add_to_group(&"writing_book")
	z_index = -3
	_seed = randi() % 10000
	rotation = randf_range(-0.5, 0.5)


func write() -> void:
	if written:
		return
	written = true
	AudioManager.play_at(&"ui_page", global_position, 4.0, 0.7)
	queue_redraw()


func interact(actor: Node) -> void:
	var player := actor as Player
	if player and player.investigation:
		if written:
			player.investigation.observe(&"writing", room.display_name if room else "")
			player.investigation.notify("Jagged symbols are scrawled across the pages.", &"evidence")
		else:
			player.investigation.notify("The notebook's pages are blank.", &"info")
	AudioManager.play(&"ui_page", -6.0)
	super.interact(actor)


func _draw() -> void:
	var r := Rect2(Vector2(-8, -6), Vector2(16, 12))
	InkStyle.draw_box(self, r, InkStyle.PAPER_MUTED, _seed, InkStyle.DETAIL_WIDTH * 1.5)
	InkStyle.draw_detail(self, Vector2(0, -6), Vector2(0, 6), _seed + 1)
	if written:
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed
		for side in [-1.0, 1.0]:
			for i in 3:
				var y := -3.0 + i * 3.0
				var x0: float = side * 1.5
				var pts := PackedVector2Array()
				for k in 5:
					pts.append(Vector2(x0 + side * k * 1.4, y + rng.randf_range(-1.2, 1.2)))
				draw_polyline(pts, InkStyle.BLOOD, 1.0)
	else:
		for i in 3:
			var y := -3.0 + i * 3.0
			draw_line(Vector2(-6, y), Vector2(-2, y), InkStyle.INK_FADED, 0.6)
			draw_line(Vector2(2, y), Vector2(6, y), InkStyle.INK_FADED, 0.6)
