extends CharacterBody2D
## A harmless basin servitor cycling between two fixed machine access points.
## It does not detect, attack or penalize Yuna; all movement is deterministic.

@export var travel_distance: float = 72.0
@export var travel_speed: float = 24.0
@export var mesa_service_route: bool = false

var _home: Vector2
var _going_down: bool = true


func _ready() -> void:
    _home = global_position
    queue_redraw()


func _physics_process(_delta: float) -> void:
    if mesa_service_route:
        # This specific, harmless machine follows a stable WORLD clock rather
        # than restarting a local patrol whenever the Basin streams back in.
        # The Mesa's optional return-signal diversion gives it a different
        # maintenance destination, not hostile AI or a punishment event.
        var phase: float = fposmod(GameSession.ecology.elapsed_minutes, 180.0) / 180.0
        var approach: float = 1.0 - absf(phase * 2.0 - 1.0)
        var target_offset: Vector2 = (Vector2(-28.0 - approach * 22.0, 46.0)
                if GameSession.mesa.service_signal_diverted
                else Vector2(approach * 102.0, 11.0))
        global_position = _home + target_offset
        velocity = Vector2.ZERO
        queue_redraw()
        return
    var target: Vector2 = _home + Vector2(0.0, travel_distance if _going_down else -travel_distance)
    if global_position.distance_to(target) < 5.0:
        _going_down = not _going_down
        target = _home + Vector2(0.0, travel_distance if _going_down else -travel_distance)
    velocity = global_position.direction_to(target) * travel_speed
    move_and_slide()
    queue_redraw()


func _draw() -> void:
    draw_circle(Vector2(0, 9), 15.0, Color("#132c34", 0.38))
    draw_rect(Rect2(-20, -14, 40, 23), Color("#547e89"))
    draw_circle(Vector2(-8, -3), 5.0, Color("#b5dde1"))
    draw_circle(Vector2(10, -3), 5.0,
        Color("#a1dcac") if mesa_service_route and GameSession.mesa.service_signal_diverted
        else Color("#80b6c3"))
    draw_line(Vector2(-21, 2), Vector2(-27, 10), Color("#34606d"), 4.0)
