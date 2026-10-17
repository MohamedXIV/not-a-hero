extends Node2D
## A small authored, persistent world interaction: identical state after chunk reload.
## No quest flag or procedural key. Chunk lifetime must never reset this switch.

const LightFactory = preload("res://scripts/presentation/light_factory.gd")

@export var persistent_id: StringName = &"world/ash_flats/relay_01"

@onready var status_light: PointLight2D = $StatusLight
var is_active: bool = false


func _ready() -> void:
    add_to_group("world_interactables")
    status_light.texture = LightFactory.radial_texture()
    is_active = GameSession.get_world_flag(persistent_id)
    _sync_visuals()


func get_interaction_label() -> String:
    if is_active:
        return "Maintenance relay is powered"
    return "E — Install handmade fuse" if GameSession.bag.quantity(&"relay_fuse") > 0 else "Relay missing fuse. Could you craft one, Yuna?"


func interact() -> bool:
    if is_active:
        GameSession.report("Still running. Good work, Yuna.")
        return false
    if not GameSession.bag.try_spend(&"relay_fuse", 1):
        GameSession.report("The relay needs a fuse. The workbench, Yuna. Think.")
        return false
    is_active = true
    GameSession.set_world_flag(persistent_id, true)
    GameSession.speak(&"repair_success")
    GameSession.report("It works. You actually fixed it.")
    _sync_visuals()
    return true


func _sync_visuals() -> void:
    status_light.enabled = is_active
    queue_redraw()


func _draw() -> void:
    # The small relay console is a provisional authored prop, not final art.
    draw_rect(Rect2(-29.0, -35.0, 58.0, 50.0), Color("#333c3e"))
    draw_rect(Rect2(-20.0, -24.0, 40.0, 19.0), Color("#72bca6") if is_active else Color("#785947"))
    draw_line(Vector2(-20, 22), Vector2(20, 22), Color("#b9aa93"), 4.0)
    draw_circle(Vector2(0, -15), 5.0, Color("#dcfff0") if is_active else Color("#df8060"))
