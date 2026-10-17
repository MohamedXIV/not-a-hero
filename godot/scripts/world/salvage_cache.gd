extends Node2D
## A single authored scavenging container. A persistent world fact prevents rerolls.

@export var persistent_id: StringName = &"world/ash_flats/scrap_cache_01"
@export var loot: Dictionary = {"scrap": 3, "wire": 1}

var looted: bool = false


func _ready() -> void:
    add_to_group("world_interactables")
    looted = GameSession.get_world_flag(persistent_id)
    queue_redraw()


func get_interaction_label() -> String:
    return "Empty salvage cache" if looted else "E — Scavenge machine parts"


func interact() -> bool:
    if looted:
        GameSession.report("Nothing left in that cache.")
        return false
    if not GameSession.bag.try_receive(loot):
        GameSession.report("Not enough room for those parts, Yuna.")
        return false
    looted = true
    GameSession.set_world_flag(persistent_id, true)
    GameSession.report("Scrap and wiring. You can make something from this, Yuna.")
    queue_redraw()
    return true


func _draw() -> void:
    draw_rect(Rect2(-28, -21, 56, 42), Color("#353e40"))
    draw_rect(Rect2(-20, -11, 40, 20), Color("#686e69") if looted else Color("#bb9360"))
    draw_line(Vector2(-23, -18), Vector2(23, 18), Color("#242b2d"), 3.0)
