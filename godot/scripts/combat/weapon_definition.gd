class_name WeaponDefinition
extends Resource
## Authorable weapon handling: no weapon-specific branches in Player or UI.

@export var weapon_id: StringName
@export var display_name: String
@export_range(1, 50) var magazine_size: int = 8
@export_range(1, 100) var damage: int = 25
@export_range(0.1, 5.0) var fire_interval: float = 0.3
@export_range(0.1, 10.0) var reload_seconds: float = 1.2
@export_range(20.0, 1500.0) var effective_range: float = 360.0
@export_range(0.0, 1200.0) var audible_radius: float = 360.0
