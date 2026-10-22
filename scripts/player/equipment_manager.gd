class_name EquipmentManager
extends Node
## Small slot-based inventory. Only the selected item is held (visible at the
## equipment anchor) and can be active.

signal inventory_changed
signal selected_changed(index: int)
signal item_state_changed(item: Equipment)

const SLOT_COUNT := 4

var player: Player
var anchor: Node2D
var slots: Array[Equipment] = []
var selected_index: int = 0


func _init() -> void:
	slots.resize(SLOT_COUNT)


func get_current() -> Equipment:
	return slots[selected_index]


func has_free_slot() -> bool:
	return slots.has(null)


func has_item(item_id: StringName) -> bool:
	for s in slots:
		if s and s.definition.id == item_id:
			return true
	return false


## Adds an item. Goes into the selected slot when it is empty, otherwise the
## first free slot. Returns null when the inventory is full.
func add_item(def: EquipmentDefinition) -> Equipment:
	var index := selected_index if slots[selected_index] == null else slots.find(null)
	if index == -1:
		return null
	var item: Equipment = def.scene.instantiate()
	item.definition = def
	item.player = player
	anchor.add_child(item)
	item.state_changed.connect(func(it: Equipment) -> void: item_state_changed.emit(it))
	slots[index] = item
	_refresh_held()
	inventory_changed.emit()
	return item


## Removes the selected item and returns its definition (null if empty).
func remove_selected() -> EquipmentDefinition:
	return remove_at(selected_index)


func remove_at(index: int) -> EquipmentDefinition:
	var item := slots[index]
	if item == null:
		return null
	item.set_active(false)
	var def := item.definition
	slots[index] = null
	item.queue_free()
	_refresh_held()
	inventory_changed.emit()
	return def


func select(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT or index == selected_index:
		return
	var previous := get_current()
	if previous:
		previous.set_active(false)
	selected_index = index
	_refresh_held()
	AudioManager.play(&"ui_click", -10.0)
	selected_changed.emit(selected_index)


func use_current() -> void:
	var item := get_current()
	if item:
		item.use()


func _refresh_held() -> void:
	for i in SLOT_COUNT:
		var item := slots[i]
		if item:
			item.set_held(i == selected_index)


## The active item of a given class, if it is the held one and switched on.
func active_item(item_id: StringName) -> Equipment:
	var item := get_current()
	if item and item.active and item.definition.id == item_id:
		return item
	return null
