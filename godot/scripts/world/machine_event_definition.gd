class_name MachineEventDefinition
extends Resource
## Region-specific optional machine routines. Never holds essential story evidence.

@export var region_id: StringName
@export var display_name: String
@export var salvage_item: ItemDefinition
@export_range(1, 5) var salvage_amount: int = 1
@export_range(60.0, 1440.0) var epoch_minutes: float = 360.0
@export_range(2, 8) var active_modulus: int = 3
@export var active_description: String = "A machine crew is working."
@export var idle_description: String = "The machinery is quiet."
