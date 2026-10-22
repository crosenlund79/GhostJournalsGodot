class_name EquipmentDefinition
extends Resource
## Data definition for a piece of investigation equipment.

@export var id: StringName
@export var display_name: String = ""
@export var short_name: String = ""
@export_multiline var description: String = ""
## Scene whose root script extends [Equipment].
@export var scene: PackedScene
## Text shown on the HUD for the F key.
@export var use_hint: String = "Toggle"
