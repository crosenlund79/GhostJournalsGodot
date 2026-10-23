class_name GhostDefinition
extends Resource
## Data-driven description of a ghost type. The shared [GhostController] reads
## these values; adding a ghost type never requires changing the controller.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_multiline var behaviour_notes: String = ""
@export var evidence: Array[StringName] = []

@export_group("Movement")
@export var roam_speed: float = 36.0
@export var hunt_speed: float = 82.0
## Speed multiplier while the ghost can see its prey during a hunt.
@export var hunt_seen_speed_multiplier: float = 1.15
## Chance that a roaming destination is inside the favourite room.
@export_range(0.0, 1.0) var favorite_room_bias: float = 0.7
## 0 = indifferent to light, 1 = strongly prefers dark rooms as a favourite room.
@export_range(0.0, 1.0) var darkness_preference: float = 0.3

@export_group("Activity")
## Seconds between environmental interactions (min, max) at full sanity.
@export var interaction_interval: Vector2 = Vector2(12.0, 22.0)
@export var door_weight: float = 1.0
@export var light_weight: float = 1.0
@export var object_weight: float = 1.0
@export var power_trip_weight: float = 0.1
## Chance per manifestation check (every few seconds while the player is near).
@export var manifestation_chance: float = 0.1
## Extra manifestation chance when the player stands in darkness.
@export var darkness_manifest_bonus: float = 0.0
## Seconds between whispers (min, max). Zero disables whispers.
@export var whisper_interval: Vector2 = Vector2.ZERO
## Multiplier applied to activity and hunt chance while the player is nearby.
@export var proximity_aggression: float = 1.0

@export_group("Hunting")
## Hunts are only possible when the player's sanity is at or below this value.
@export var hunt_sanity_threshold: float = 50.0
## Base chance per hunt check once the threshold is reached.
@export var hunt_chance: float = 0.12
@export var hunt_duration: Vector2 = Vector2(22.0, 30.0)
@export_range(0.0, 1.0) var hunt_power_trip_chance: float = 0.2

@export_group("Evidence")
@export_range(0.0, 1.0) var emf5_chance: float = 0.4
@export_range(0.0, 1.0) var uv_print_chance: float = 0.6
@export_range(0.0, 1.0) var writing_chance: float = 0.5
@export_range(0.0, 1.0) var spirit_box_chance: float = 0.45
@export var spirit_box_phrases: PackedStringArray = PackedStringArray(["...here...", "...close...", "...leave..."])

@export_group("Presentation")
@export var voice_pitch: float = 1.0
@export var silhouette_scale: float = 1.0
## Hand-drawn token shown while the ghost is visible (drawn upright, facing the
## viewer). Leave empty to use the procedural silhouette.
@export var sprite: Texture2D
## On-screen height of the token in world pixels (1 tile = 32 px).
@export var sprite_world_height: float = 50.0
## Leaves a trail of smoke behind it while visible and moving.
@export var smoke_trail: bool = true
## Jump scare when it catches the investigator: a splash image that lunges
## from the ghost to the screen, and the sound played with it. Without a
## splash image the procedural "horror face" is shown instead.
@export var caught_sprite: Texture2D
@export var caught_sound: AudioStream


func has_evidence(evidence_id: StringName) -> bool:
	return evidence.has(evidence_id)
