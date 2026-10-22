class_name RitualKit
extends Equipment
## Salt and candles for the rite of expulsion. F lays the circle at the
## investigator's feet (inside the house), consuming the kit.

signal place_requested(kit: RitualKit, world_position: Vector2)


func use() -> void:
	if player == null or player.house == null:
		return
	var pos := player.global_position + player.facing * 10.0
	var room := player.house.get_room_at(pos)
	if room == null or room.is_outdoors:
		if player.investigation:
			player.investigation.notify("The circle must be laid inside the house.", &"info")
		return
	if room.is_safe_room:
		if player.investigation:
			player.investigation.notify("It will never come here. Lay the circle where it dwells.", &"info")
		return
	place_requested.emit(self, pos)
	get_tree().call_group(&"investigation", &"request_ritual_circle", self, pos)


func get_hud_reading() -> String:
	return "F — lay circle"


func _draw_placeholder() -> void:
	InkStyle.draw_box(self, Rect2(Vector2(-5, -4), Vector2(10, 8)), InkStyle.PAPER_MUTED, 71, InkStyle.DETAIL_WIDTH)
	draw_circle(Vector2(0, 0), 1.6, InkStyle.BLOOD)
