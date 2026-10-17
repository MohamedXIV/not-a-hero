extends Node2D
## One working station, not a menu pretending to craft.

@export var recipe: RecipeDefinition = preload("res://resources/recipes/relay_fuse.tres")


func get_interaction_label() -> String:
    return "E — Craft relay fuse (3 scrap + 1 wire)"


func interact() -> bool:
    if not GameSession.condition.can_focus():
        GameSession.report("Not now, Yuna. You're shaking. Rest, then try again.")
        return false
    if not GameSession.bag.try_craft(recipe):
        GameSession.report("Not enough materials. Three scraps and some wire, Yuna.")
        return false
    GameSession.report("A working relay fuse. Hah! Nicely done, Yuna.")
    return true


func _draw() -> void:
    draw_rect(Rect2(-12, -12, 24, 24), Color("#394d53"))
    draw_circle(Vector2.ZERO, 5.0, Color("#f0bb73"))
