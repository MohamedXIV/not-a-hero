class_name DecorDefinition
extends Resource
## Godot-authored decor vocabulary; no hardcoded item colors/footprints in controller.

@export var kind_id: StringName
@export var inventory_item: ItemDefinition
@export var display_name: String
@export var footprint: Vector2 = Vector2(24, 24)
@export var tint: Color = Color.WHITE
@export var obstructs_movement: bool = false
@export var emits_light: bool = false
