class_name Interactable
extends Node2D
## Shared interaction contract. Anything the player can use with E extends
## this: doors, the fuse box, equipment pickups, notebooks, the ritual circle,
## the exit. The [InteractionSystem] on the player finds, highlights and drives
## these objects; subclasses only override the virtual methods below.

signal interacted(actor: Node)

@export var prompt_text: String = "Interact"
@export var interaction_range: float = 46.0
## Seconds the key must be held. 0 = instant interaction.
@export var hold_duration: float = 0.0
@export var interaction_enabled: bool = true
## Extent of the highlight brackets drawn around the object.
@export var highlight_extent: Vector2 = Vector2(14, 14)

var highlighted: bool = false
var _highlight: InteractionHighlight


func _ready() -> void:
	add_to_group(&"interactable")
	_highlight = InteractionHighlight.new()
	_highlight.extent = highlight_extent
	_highlight.visible = false
	_highlight.z_index = 30
	add_child(_highlight)


## World position used for range and line-of-sight checks.
func get_interaction_position() -> Vector2:
	return global_position


func can_interact(_actor: Node) -> bool:
	return interaction_enabled and is_visible_in_tree()


func get_prompt(_actor: Node) -> String:
	return prompt_text


func interact(actor: Node) -> void:
	interacted.emit(actor)


## Called every frame while a hold interaction is in progress. Returning false
## pauses progress (it does not cancel the hold).
func can_continue_hold(_actor: Node) -> bool:
	return true


func on_hold_started(_actor: Node) -> void:
	pass


func on_hold_cancelled(_actor: Node) -> void:
	pass


## Optional extra status line shown under the prompt during a hold.
func get_hold_status(_actor: Node) -> String:
	return ""


func set_highlighted(value: bool) -> void:
	highlighted = value
	if _highlight:
		_highlight.extent = highlight_extent
		_highlight.visible = value
		_highlight.queue_redraw()
