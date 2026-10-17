extends Node2D
## Fixed mesa landmark. Visible physical maintenance damage suggests why
## machines want entry; neither opening path depends on journal/RNG.
## E = inspect/slow emergency release. Q = optional spare relay-fuse route.

const WORK_MINUTES: float = 20.0


func _ready() -> void:
    add_to_group("world_interactables")
    queue_redraw()


func can_enter() -> bool:
    return GameSession.mesa.is_open()


func get_interaction_label() -> String:
    if GameSession.mesa.is_open():
        return "E — Enter the hidden mesa refuge"
    if not GameSession.mesa.inspected:
        return "E — Examine scored maintenance hatch"
    return "E — Work the handwheel (%d/3) | Q — bridge using relay fuse" % GameSession.mesa.manual_progress


func interact() -> bool:
    if GameSession.mesa.is_open():
        return false # Outdoor scene handles the level transition.
    if GameSession.mesa.examine():
        GameSession.speak(&"mesa_hatch_found")
        GameSession.report("Scored hinges. A handwheel... and an unused fuse bridge.")
        queue_redraw()
        return true
    if not GameSession.mesa.turn_handwheel():
        return false
    GameSession.advance_time(WORK_MINUTES)
    if GameSession.mesa.is_open():
        GameSession.speak(&"mesa_access_open")
        GameSession.report("The manual cams finally released. You did that, Yuna.")
    else:
        var names: Array[String] = ["Venting old pressure.", "The secondary cam is aligned."]
        GameSession.report(names[GameSession.mesa.manual_progress - 1])
    queue_redraw()
    return true


func install_fuse() -> bool:
    if not GameSession.mesa.inspected or GameSession.mesa.is_open():
        return false
    if not GameSession.mesa.install_fuse(GameSession.bag):
        GameSession.report("No relay fuse. The emergency handwheel still works.")
        return false
    GameSession.speak(&"mesa_access_open")
    GameSession.report("The coupler wakes up. The lock releases. Well done, Yuna.")
    queue_redraw()
    return true


func _draw() -> void:
    # Enlarged door with visible pry marks, hydraulic cams and spare coupler.
    draw_rect(Rect2(-81, -72, 162, 135), Color("#211f20"))
    draw_rect(Rect2(-64, -57, 128, 109), Color("#4b4c47") if GameSession.mesa.is_open() else Color("#272f36"))
    draw_rect(Rect2(-52, -45, 104, 89), Color("#101c22") if GameSession.mesa.is_open() else Color("#55616a"))
    for y: int in [-31, -10, 11, 31]:
        draw_line(Vector2(-47, y), Vector2(47, y), Color("#8c8e79"), 3.0)
    draw_circle(Vector2(-77, 34), 17, Color("#b39368"))
    draw_arc(Vector2(-77, 34), 10, 0, TAU, 25, Color("#414241"), 4.0)
    draw_rect(Rect2(65, 11, 27, 39), Color("#494e50"))
    draw_circle(Vector2(79, 26), 6, Color("#9cdec5") if GameSession.mesa.is_open() else Color("#a97153"))
    for offset: int in range(3):
        draw_line(Vector2(19 + offset * 14, -60), Vector2(29 + offset * 14, -77), Color("#bd8977"), 3.0)
    if GameSession.mesa.is_open():
        draw_line(Vector2(-36, -44), Vector2(-36, 42), Color("#a2d9bc"), 4.0)
