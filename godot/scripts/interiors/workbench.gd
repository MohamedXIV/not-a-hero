extends Node2D

const DRESSING_RECIPE: RecipeDefinition = preload("res://resources/recipes/field_dressing.tres")
## One working station, not a menu pretending to craft.

@export var recipe: RecipeDefinition = preload("res://resources/recipes/relay_fuse.tres")


func get_interaction_label() -> String:
    return "E — Relay fuse (3 scrap + 1 wire) | C — Dressing (2 fibers)"


func interact() -> bool:
    if not GameSession.condition.can_focus():
        GameSession.speak(&"focus_lost")
        GameSession.report("Not now, Yuna. You're shaking. Rest, then try again.")
        return false
    if not GameSession.bag.try_craft(recipe):
        GameSession.report("Not enough materials. Three scraps and some wire, Yuna.")
        return false
    GameSession.speak(&"craft_success")
    GameSession.report("A working relay fuse. Hah! Nicely done, Yuna.")
    return true


func craft_field_dressing() -> bool:
    if not GameSession.condition.can_focus():
        GameSession.speak(&"focus_lost")
        GameSession.report("Your hands need a moment. Rest first, Yuna.")
        return false
    if not GameSession.bag.try_craft(DRESSING_RECIPE):
        GameSession.report("Two culture fibers make one clean dressing.")
        return false
    GameSession.speak(&"craft_success")
    GameSession.report("Another clean dressing. Just in case, Yuna.")
    return true


func _draw() -> void:
    draw_rect(Rect2(-12, -12, 24, 24), Color("#394d53"))
    draw_circle(Vector2.ZERO, 5.0, Color("#f0bb73"))
