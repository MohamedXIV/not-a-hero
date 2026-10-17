extends Node2D
## Hand-authored inspectable mechanical evidence at a fixed position.
## Does not dispense quest markers or procedural critical clues.

@export var discovery: DiscoveryDefinition


func _ready() -> void:
    add_to_group("world_interactables")
    queue_redraw()


func get_interaction_label() -> String:
    if discovery == null:
        return ""
    if GameSession.notebook.knows(String(discovery.discovery_id)):
        return "E — Re-examine " + discovery.title
    return "E — Examine " + discovery.title


func interact() -> bool:
    if discovery == null:
        return false
    var first_time: bool = GameSession.notebook.discover(String(discovery.discovery_id))
    if first_time:
        GameSession.speak(discovery.bark_event)
        GameSession.report("Noted. N opens your notebook, Yuna.")
        queue_redraw()
    else:
        GameSession.report("You've already written down what you saw here.")
    return first_time


func _draw() -> void:
    # Provisional physical artifact; geometry is authored, not RNG-populated.
    draw_rect(Rect2(-30, -16, 60, 29), Color("#4d5554"))
    draw_line(Vector2(-26, 2), Vector2(26, 2), Color("#a5b7a1"), 4.0)
    draw_circle(Vector2(12, -5), 5.0, Color("#9fd2c4") if (discovery != null
        and GameSession.notebook.knows(String(discovery.discovery_id))) else Color("#bb8b65"))
