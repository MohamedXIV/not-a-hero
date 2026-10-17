extends Node2D
## First functional home storage. E deposits entire bag, Shift+E retrieves.
## Both operations are one atomic inventory transaction; UI refinement later.


func get_interaction_label() -> String:
    return "E — Store bag | Shift+E — Take stored items"


func interact(withdraw: bool = false) -> bool:
    var source: InventoryState = GameSession.storage if withdraw else GameSession.bag
    var destination: InventoryState = GameSession.bag if withdraw else GameSession.storage
    if not source.try_transfer_all(destination):
        GameSession.report("No room, or nothing to move, Yuna.")
        return false
    GameSession.report("You sorted the supplies. Good, Yuna.")
    return true


func _draw() -> void:
    draw_rect(Rect2(-34, -21, 68, 42), Color("#4e3b31"))
    draw_rect(Rect2(-29, -15, 58, 30), Color("#896f52"))
    draw_line(Vector2(-29, -7), Vector2(29, -7), Color("#c3a783"), 3.0)
    draw_circle(Vector2(0, -5), 4.0, Color("#cfbb82"))
