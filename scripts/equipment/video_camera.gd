class_name VideoCamera
extends Equipment
## Handheld night-vision camera. While recording, the screen shows the camera
## overlay and [GhostOrb]s inside the camera's frame become visible.

signal recording_changed(on: bool)

const VIEW_RANGE := 300.0
const HALF_FOV := deg_to_rad(38.0)


func _on_activated() -> void:
	_notify(true)


func _on_deactivated() -> void:
	_notify(false)


func _exit_tree() -> void:
	if active:
		_notify(false)


func _notify(on: bool) -> void:
	recording_changed.emit(on)
	if is_inside_tree():
		get_tree().call_group(&"investigation", &"on_camera_recording", on)


func sees_point(point: Vector2) -> bool:
	if not active:
		return false
	var to := point - global_position
	if to.length() > VIEW_RANGE:
		return false
	var forward := Vector2.RIGHT.rotated(global_rotation)
	if absf(forward.angle_to(to)) > HALF_FOV:
		return false
	var space := get_world_2d().direct_space_state
	return space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, point, 1)).is_empty()


func _physics_process(_delta: float) -> void:
	if not active:
		return
	for node in get_tree().get_nodes_in_group(&"ghost_orb"):
		var orb := node as GhostOrb
		if orb and sees_point(orb.global_position):
			orb.mark_seen()
			if orb.seen_amount >= 0.6 and player and player.investigation:
				player.investigation.observe(&"orbs", orb.room.display_name if orb.room else "")


func get_hud_reading() -> String:
	return "REC" if active else "off"


func _draw_placeholder() -> void:
	InkStyle.draw_box(self, Rect2(Vector2(-6, -4), Vector2(11, 8)), InkStyle.INK.lightened(0.18), 51, InkStyle.DETAIL_WIDTH)
	InkStyle.draw_oval(self, Vector2(6, 0), Vector2(2.5, 3), InkStyle.fill(&"metal"), 52, InkStyle.DETAIL_WIDTH)
