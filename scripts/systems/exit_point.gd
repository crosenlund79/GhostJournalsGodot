class_name ExitPoint
extends Interactable
## The investigation van's door. Holding E ends the investigation.

signal exit_requested


func _ready() -> void:
	hold_duration = 1.5
	interaction_range = 46.0
	highlight_extent = Vector2(10, 16)
	prompt_text = "End the Investigation and Leave"
	super._ready()


func interact(actor: Node) -> void:
	exit_requested.emit()
	super.interact(actor)


func _draw() -> void:
	InkStyle.draw_box(self, Rect2(Vector2(-4, -14), Vector2(6, 28)), InkStyle.fill(&"vehicle").darkened(0.3), 8080, InkStyle.DETAIL_WIDTH)
	draw_line(Vector2(0, -3), Vector2(0, 3), InkStyle.PAPER_MUTED, 2.0)
