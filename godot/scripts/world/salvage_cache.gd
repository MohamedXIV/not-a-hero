extends Node2D
## A single authored scavenging container. A persistent world fact prevents rerolls.

@export var persistent_id: StringName = &"world/ash_flats/scrap_cache_01"
@export var loot: Dictionary = {"scrap": 3, "wire": 1}
@export var loot_table: LootTableDefinition

var _rolled_loot: Dictionary = {}

var looted: bool = false


func _ready() -> void:
    add_to_group("world_interactables")
    looted = GameSession.get_world_flag(persistent_id)
    _rolled_loot = loot_table.roll(GameSession.world_seed, persistent_id) if loot_table != null else loot.duplicate(true)
    queue_redraw()


func get_interaction_label() -> String:
    return "Empty salvage cache" if looted else "E — Scavenge machine parts"


func interact() -> bool:
    if looted:
        GameSession.report("Nothing left in that cache.")
        return false
    if _rolled_loot.is_empty():
        GameSession.report("Only dust in this compartment, Yuna.")
        return false
    if not GameSession.bag.try_receive(_rolled_loot):
        GameSession.report("Not enough room for those parts, Yuna.")
        return false
    looted = true
    GameSession.set_world_flag(persistent_id, true)
    GameSession.speak(&"salvage_found")
    GameSession.report("A few useful parts. Good eyes, Yuna.")
    queue_redraw()
    return true


func _draw() -> void:
    draw_rect(Rect2(-28, -21, 56, 42), Color("#353e40"))
    draw_rect(Rect2(-20, -11, 40, 20), Color("#686e69") if looted else Color("#bb9360"))
    draw_line(Vector2(-23, -18), Vector2(23, 18), Color("#242b2d"), 3.0)
