class_name InnerMonologue
extends Node
## The investigator's inner voice. Every time composure falls past another
## 10% mark it says something, growing more certain that a hunt is coming.
## Crossing below the entity's hunt threshold produces the clearest warning.
## A mark re-arms once composure has recovered 5% above it.

signal spoke(text: String)

const LINES := {
	90: "Something in this house knows I'm here. I can feel it watching.",
	80: "My hands won't stop shaking. Keep it together.",
	70: "I can feel myself losing composure... and something here is enjoying it.",
	60: "I can sense the being thriving on my unease. Every heartbeat feeds it.",
	50: "It's getting bolder. I can feel it circling closer.",
	40: "It's so close now. I think it's working itself up to come for me.",
	30: "I can't breathe. It's feeding on my fear. It could hunt me any second.",
	20: "It's going to hunt me. I need light. I need the warded room.",
	10: "There's nothing left to hide behind. It's coming.",
}
const HUNT_READY_LINE := "It has fed enough on my fear. It can hunt me now. I have to be ready to run."

var player: Player
var hunt_threshold: float = 50.0
var _spoken: Dictionary = {}
var _hunt_warned: bool = false


func setup(target_player: Player, ghost_hunt_threshold: float) -> void:
	player = target_player
	hunt_threshold = ghost_hunt_threshold
	player.sanity.sanity_changed.connect(_on_sanity_changed)


func _on_sanity_changed(value: float) -> void:
	# Re-arm marks the investigator has recovered from.
	for level in _spoken.keys():
		if value > level + 5.0:
			_spoken.erase(level)
	if _hunt_warned and value > hunt_threshold + 5.0:
		_hunt_warned = false
	# On a big drop several marks pass at once: speak for the lowest.
	var crossed := 999
	for level in LINES.keys():
		if value <= level and not _spoken.has(level):
			_spoken[level] = true
			crossed = mini(crossed, level)
	if crossed == 999:
		return
	if not _hunt_warned and value <= hunt_threshold:
		_hunt_warned = true
		spoke.emit(HUNT_READY_LINE)
	else:
		spoke.emit(LINES[crossed])
