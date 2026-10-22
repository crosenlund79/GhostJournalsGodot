class_name GameBalance
extends Resource
## Tunable numbers for sanity, hunts and pacing. Kept in one resource so the
## formulas stay understandable and configurable without touching code.

@export_group("Sanity drain (per second)")
## Standing in an unlit room with no handheld light.
@export var darkness_drain: float = 0.12
## Standing in an unlit room with a flashlight on (partial protection).
@export var flashlight_darkness_drain: float = 0.05
## Multiplier applied to darkness drain while the house has no power.
@export var power_out_multiplier: float = 1.35
## Drain while the ghost is close (not hunting).
@export var ghost_proximity_drain: float = 0.15
@export var ghost_proximity_radius: float = 110.0
## Recovery while inside a protected safe room.
@export var safe_room_recovery: float = 0.4

@export_group("Sanity shocks")
@export var manifestation_seen_loss: float = 7.0
@export var manifestation_unseen_loss: float = 2.5
@export var event_witness_loss: float = 2.0
@export var hunt_start_loss: float = 4.0
@export var spirit_box_response_loss: float = 3.0

@export_group("Pacing")
## Seconds after arrival during which the ghost stays dormant.
@export var dormant_duration: float = 15.0
@export var hunt_cooldown: float = 35.0
## No hunt can begin before this many seconds into the investigation.
@export var first_hunt_delay: float = 120.0
@export var hunt_check_interval: float = 5.0
## Seconds at the start of a hunt during which the ghost does not move.
@export var hunt_grace_period: float = 3.0
@export var manifestation_check_interval: float = 4.0
## Ghost activity is multiplied by 1 + (1 - sanity/100) * this value.
@export var low_sanity_activity_bonus: float = 1.5

@export_group("Player")
@export var walk_speed: float = 105.0
@export var sprint_speed: float = 158.0
@export var stamina_seconds: float = 3.0
@export var stamina_recovery_per_second: float = 0.25


func activity_multiplier(sanity: float) -> float:
	return 1.0 + (1.0 - clampf(sanity, 0.0, 100.0) / 100.0) * low_sanity_activity_bonus
