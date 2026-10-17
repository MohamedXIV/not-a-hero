class_name ItemDefinition
extends Resource
## Immutable item design data, authored in Godot Resources.

@export var item_id: StringName
@export var display_name: String
@export_range(1, 99) var max_stack: int = 99
