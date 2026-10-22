class_name UvFlashlight
extends Flashlight
## Narrow ultraviolet beam. Reveals [UvPrint]s inside the beam; prints are
## otherwise invisible.


func _init() -> void:
	beam_range = 190.0
	half_angle = deg_to_rad(20.0)
	beam_color = InkStyle.LIGHT_UV
	beam_energy = 0.75


func _physics_process(_delta: float) -> void:
	if not active:
		return
	for node in get_tree().get_nodes_in_group(&"uv_print"):
		var p := node as UvPrint
		if p and illuminates(p.global_position):
			p.illuminate()
			if p.reveal >= 0.5 and player and player.investigation:
				player.investigation.observe(&"uv_prints", p.room_name)


func get_hud_reading() -> String:
	return "UV on" if active else "off"


func _draw_placeholder() -> void:
	InkStyle.draw_box(self, Rect2(Vector2(-4, -2.5), Vector2(10, 5)), InkStyle.PAPER_DARK, 21, InkStyle.DETAIL_WIDTH)
	InkStyle.draw_box(self, Rect2(Vector2(5, -3.5), Vector2(3, 7)), InkStyle.LIGHT_UV.darkened(0.5), 22, InkStyle.DETAIL_WIDTH)
