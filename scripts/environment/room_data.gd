class_name RoomData
extends RefCounted
## Runtime description of one room. Rooms are identified from the layout grid.

var key: String = ""
var id: StringName
var display_name: String = ""
var floor_type: StringName = &"wood"
var light_energy: float = 0.8
var base_temperature: float = 18.0
var temperature: float = 18.0
var can_be_favorite: bool = true
var is_outdoors: bool = false
var is_safe_room: bool = false
var cells: Array[Vector2i] = []
var bounds: Rect2i
## Light switch state. The room is only lit when this is on AND power is on.
var light_switch_on: bool = true
var lights: Array[PointLight2D] = []
var neighbors: Array[RoomData] = []
var switch_cell: Vector2i = Vector2i(-1, -1)


func center_world() -> Vector2:
	var sum := Vector2.ZERO
	for c in cells:
		sum += Vector2(c)
	sum /= maxf(1.0, float(cells.size()))
	return (sum + Vector2(0.5, 0.5)) * InkStyle.TILE


func has_cell(cell: Vector2i) -> bool:
	return cells.has(cell)
