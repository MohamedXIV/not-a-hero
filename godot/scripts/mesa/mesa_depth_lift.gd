class_name MesaDepthLift
extends Node2D
## A visible service lift/door at the far end of the restored rear gallery.
## No hidden rare key: a slow hand-release or already-diverted maintenance
## return. Leaving the choice alone never locks Yuna out of her homes.

signal enter_requested

const RADIUS: float = 58.0
const WORK_MINUTES: float = 40.0


func _ready() -> void:
    queue_redraw()


func near(player: Vector2) -> bool:
    return global_position.distance_to(player) < RADIUS


func hint_at(player: Vector2) -> String:
    if not near(player):
        return ""
    if not GameSession.mesa.flow_online():
        return "Lower service lift — pressure isolation must be restored."
    if not GameSession.mesa.depth_open:
        return ("E — Open lower lift using the redirected service return"
                if GameSession.mesa.service_signal_diverted
                else "E — Manually release lower service lift (40 minutes)")
    return "E — Descend into the lower thermal gallery"


func interact_at(player: Vector2) -> bool:
    if not near(player):
        return false
    if not GameSession.mesa.flow_online():
        GameSession.report("The old pressure seal is still live. Fix circulation first.")
        return true
    if GameSession.mesa.unlock_depth():
        if not GameSession.mesa.service_signal_diverted:
            GameSession.advance_time(WORK_MINUTES)
        GameSession.speak(&"mesa_depth_opened")
        GameSession.report("A service stair, not a vault. The lower gallery is open.")
        GameSession.save_to_disk()
        queue_redraw()
        return true
    enter_requested.emit()
    return true


func _draw() -> void:
    draw_rect(Rect2(-38, -30, 76, 60), Color("#202d36"))
    draw_rect(Rect2(-29, -23, 58, 44),
        Color("#31494a") if GameSession.mesa.depth_open else Color("#65737c"))
    for stripe: int in range(3):
        draw_line(Vector2(-23, -12 + stripe * 13), Vector2(22, -12 + stripe * 13),
            Color("#b0bfc4") if GameSession.mesa.depth_open else Color("#5e6465"), 3.0)
    draw_circle(Vector2(29, -24), 6.0,
        Color("#a7d8af") if GameSession.mesa.depth_open else Color("#d4aa73"))
