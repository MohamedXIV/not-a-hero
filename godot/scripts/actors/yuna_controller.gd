extends CharacterBody2D
## Provisional readable Yuna shape. Replace with animated artwork after art-style spike.
## Movement collision uses feet; future hit locations are a separate injury concern.

@export var walking_speed: float = 158.0
@export var sprint_multiplier: float = 1.35

var _facing_right: bool = true
var _walking: bool = false
var _stagger_left: float = 0.0
var hits_taken: int = 0


func _ready() -> void:
    add_to_group("yuna_actor")


func receive_robot_hit() -> void:
    if _stagger_left > 0.0:
        return
    hits_taken += 1
    _stagger_left = 0.65
    GameSession.report("Ow! Move, Yuna. Find cover!")


func is_staggered() -> bool:
    return _stagger_left > 0.0


func _physics_process(delta: float) -> void:
    _stagger_left = maxf(0.0, _stagger_left - delta)
    var direction: Vector2 = Input.get_vector(
        "move_left", "move_right", "move_up", "move_down"
    )
    _walking = direction.length_squared() > 0.01
    if direction.x != 0.0:
        _facing_right = direction.x > 0.0
    var speed: float = walking_speed
    if Input.is_action_pressed("sprint"):
        speed *= sprint_multiplier
    if _stagger_left > 0.0:
        speed *= 0.55
    velocity = direction * speed
    move_and_slide()
    queue_redraw()


func _draw() -> void:
    var step_offset: float = sin(Time.get_ticks_msec() * 0.014) * 2.0 if _walking else 0.0
    # Feet/shadow, boots, soft tunic, pale face, auburn hair and braid.
    draw_ellipse_shadow()
    draw_line(Vector2(-8, -5), Vector2(-8, 7 + step_offset), Color("#646e69"), 7.0)
    draw_line(Vector2(8, -5), Vector2(8, 7 - step_offset), Color("#646e69"), 7.0)
    draw_colored_polygon(PackedVector2Array([
        Vector2(-15, -35), Vector2(14, -35),
        Vector2(18, -5), Vector2(-17, -5),
    ]), Color("#ba927f"))
    draw_line(Vector2(-15, -29), Vector2(-23, -11), Color("#e1bda4"), 6.0)
    draw_line(Vector2(15, -29), Vector2(21, -10), Color("#e1bda4"), 6.0)
    draw_circle(Vector2(0, -49), 14.0, Color("#e4c3a7"))
    draw_arc(Vector2(0, -51), 14.0, PI, TAU, 18, Color("#82523b"), 8.0)
    var braid_x: float = 16.0 if _facing_right else -16.0
    draw_line(Vector2(braid_x * 0.6, -52), Vector2(braid_x, -24), Color("#92583f"), 7.0)
    draw_circle(Vector2(-4, -49), 1.6, Color("#7a9d85"))
    draw_circle(Vector2(5, -49), 1.6, Color("#7a9d85"))


func draw_ellipse_shadow() -> void:
    draw_circle(Vector2(0, 7), 15.0, Color(0.0, 0.0, 0.0, 0.25))
