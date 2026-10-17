extends CharacterBody2D
## Harmless environmental worker: no hostile perception, damage or chase.

var _origin: Vector2
var _to_right: bool = true


func _ready() -> void:
    _origin = global_position


func _physics_process(_delta: float) -> void:
    var goal: Vector2 = _origin + Vector2(35 if _to_right else -35, 0)
    if global_position.distance_to(goal) < 6.0:
        _to_right = not _to_right
    velocity = global_position.direction_to(goal) * 28.0
    move_and_slide()
    queue_redraw()


func _draw() -> void:
    draw_circle(Vector2(0, 8), 12.0, Color("#1c2429", 0.35))
    draw_rect(Rect2(-14, -18, 28, 28), Color("#75968e"))
    draw_circle(Vector2(4, -8), 4.5, Color("#bcddb1"))
