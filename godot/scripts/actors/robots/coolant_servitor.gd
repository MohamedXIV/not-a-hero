extends CharacterBody2D
## A harmless basin servitor cycling between two fixed machine access points.
## It does not detect, attack or penalize Yuna; all movement is deterministic.

@export var travel_distance: float = 72.0
@export var travel_speed: float = 24.0

var _home: Vector2
var _going_down: bool = true


func _ready() -> void:
    _home = global_position
    queue_redraw()


func _physics_process(_delta: float) -> void:
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
    draw_circle(Vector2(10, -3), 5.0, Color("#80b6c3"))
    draw_line(Vector2(-21, 2), Vector2(-27, 10), Color("#34606d"), 4.0)
