class_name InteractionSystem
extends Node
## Player component: picks the best interactable in range, highlights it,
## exposes the context prompt and handles instant and hold interactions.

signal focus_changed(target: Interactable)

const LOS_MASK := 1

var actor: Player
var focused: Interactable
var hold_progress: float = 0.0
var holding: bool = false
var _hold_time: float = 0.0


func _physics_process(delta: float) -> void:
	if actor == null:
		return
	if not actor.can_act():
		cancel_hold()
		_set_focus(null)
		return
	if not holding:
		_set_focus(_find_best())
	if focused == null or not is_instance_valid(focused):
		cancel_hold()
		focused = null
		return
	if not holding and Input.is_action_just_pressed(&"interact_alt") and focused.get_secondary_prompt(actor) != "":
		focused.secondary_interact(actor)
		return
	if Input.is_action_just_pressed(&"interact"):
		if focused.hold_duration <= 0.0:
			focused.interact(actor)
		else:
			holding = true
			_hold_time = 0.0
			focused.on_hold_started(actor)
	if holding:
		if not Input.is_action_pressed(&"interact") or not focused.can_interact(actor) \
				or actor.global_position.distance_to(focused.get_interaction_position()) > focused.interaction_range + 12.0:
			cancel_hold()
			return
		if focused.can_continue_hold(actor):
			_hold_time += delta
		hold_progress = clampf(_hold_time / focused.hold_duration, 0.0, 1.0)
		if _hold_time >= focused.hold_duration:
			var target := focused
			holding = false
			hold_progress = 0.0
			_hold_time = 0.0
			target.interact(actor)


## Starts or completes interaction programmatically (used by automated tests).
func force_interact(target: Interactable) -> void:
	if target and target.can_interact(actor):
		target.interact(actor)


func cancel_hold() -> void:
	if holding and focused and is_instance_valid(focused):
		focused.on_hold_cancelled(actor)
	holding = false
	hold_progress = 0.0
	_hold_time = 0.0


func _set_focus(target: Interactable) -> void:
	if target == focused:
		return
	if focused and is_instance_valid(focused):
		focused.set_highlighted(false)
	focused = target
	if focused:
		focused.set_highlighted(true)
	focus_changed.emit(focused)


func _find_best() -> Interactable:
	var best: Interactable = null
	var best_score := INF
	var origin := actor.global_position
	for node in actor.get_tree().get_nodes_in_group(&"interactable"):
		var it := node as Interactable
		if it == null or not it.can_interact(actor):
			continue
		var target_pos := it.get_interaction_position()
		var to := target_pos - origin
		var dist := to.length()
		if dist > it.interaction_range:
			continue
		# Prefer what the player is facing.
		var facing_bonus := actor.facing.dot(to.normalized()) if dist > 1.0 else 1.0
		var score := dist - facing_bonus * 14.0
		if score < best_score and _has_reach(origin, target_pos):
			best_score = score
			best = it
	return best


func _has_reach(from: Vector2, to: Vector2) -> bool:
	var space := actor.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to, LOS_MASK)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true
	# Wall-mounted objects and doors sit on/inside colliders; accept hits right at the target.
	return (hit["position"] as Vector2).distance_to(to) < 18.0


func get_prompt_text() -> String:
	if focused == null or not is_instance_valid(focused):
		return ""
	var p := focused.get_prompt(actor)
	if p == "":
		return ""
	var verb := "Hold E" if focused.hold_duration > 0.0 else "E"
	var text := "%s — %s" % [verb, p]
	var alt := focused.get_secondary_prompt(actor)
	if alt != "":
		text += "      R — %s" % alt
	return text


func get_hold_status() -> String:
	if holding and focused and is_instance_valid(focused):
		return focused.get_hold_status(actor)
	return ""
