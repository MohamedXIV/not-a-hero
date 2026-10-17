extends CharacterBody2D
## First hostile machine: short readable state machine with sight, hearing, retreat.
## Defeated robot persists by stable world flag; no automatic surprise respawns.

signal destroyed

@export var persistent_id: StringName = &"world/cable_forest/survey_guard_01"
@export_range(1, 500) var max_durability: int = 120
@export var sight_range: float = 230.0
@export var disengage_range: float = 340.0
@export var walking_speed: float = 54.0
@export var pursuit_speed: float = 105.0

var durability: int = 120
var state: StringName = &"patrol"
var _home: Vector2
var _patrol_right: bool = true
var _last_known_position: Vector2
var _search_remaining: float = 0.0
var _attack_cooldown: float = 0.0
var _target: CharacterBody2D


func _ready() -> void:
    if GameSession.get_world_flag(persistent_id):
        queue_free()
        return
    add_to_group("robot_sensors")
    durability = max_durability
    _home = global_position
    _last_known_position = _home


func has_line_of_sight(target: Node2D) -> bool:
    if target == null or global_position.distance_to(target.global_position) > sight_range:
        return false
    var start: Vector2 = global_position + Vector2(0, -12)
    var end: Vector2 = target.global_position + Vector2(0, -12)
    var query := PhysicsRayQueryParameters2D.create(start, end, 1 | 2)
    var result: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
    return not result.is_empty() and result.get("collider") == target


func hear_noise(position: Vector2, radius: float) -> void:
    if global_position.distance_to(position) > radius or state == &"pursue":
        return
    _last_known_position = position
    _search_remaining = 4.0
    state = &"investigate"


func take_damage(amount: int) -> void:
    if amount <= 0 or durability <= 0:
        return
    durability = maxi(0, durability - amount)
    if durability == 0:
        GameSession.set_world_flag(persistent_id, true)
        GameSession.report("One less machine hunting you, Yuna.")
        destroyed.emit()
        queue_free()
        return
    _last_known_position = _find_yuna_position()
    _search_remaining = 5.0
    state = &"investigate"


func _find_yuna_position() -> Vector2:
    var actor: Node2D = get_tree().get_first_node_in_group("yuna_actor") as Node2D
    return actor.global_position if actor != null else global_position


func _physics_process(delta: float) -> void:
    if GameSession.get_world_flag(persistent_id):
        return
    _attack_cooldown = maxf(0.0, _attack_cooldown - delta)
    if _target == null or not is_instance_valid(_target):
        _target = get_tree().get_first_node_in_group("yuna_actor") as CharacterBody2D
    var seen: bool = GameSession.current_level == "outdoors" and has_line_of_sight(_target)
    if seen:
        _last_known_position = _target.global_position
        _search_remaining = 3.5
        state = &"pursue"
    elif state == &"pursue":
        state = &"investigate"
    if state == &"investigate":
        _search_remaining -= delta
        if global_position.distance_to(_last_known_position) < 22.0 or _search_remaining <= 0.0:
            state = &"return"
    if state == &"pursue" and is_instance_valid(_target):
        if global_position.distance_to(_home) > 550.0 or global_position.distance_to(_target.global_position) > disengage_range:
            state = &"return"
        else:
            _walk_to(_target.global_position, pursuit_speed)
            if global_position.distance_to(_target.global_position) < 36.0 and _attack_cooldown == 0.0:
                _attack_cooldown = 2.3
                _target.call("receive_robot_hit")
            queue_redraw()
            return
    if state == &"investigate":
        _walk_to(_last_known_position, walking_speed * 1.15)
    elif state == &"return":
        _walk_to(_home, walking_speed)
        if global_position.distance_to(_home) < 12.0:
            state = &"patrol"
    else:
        var destination: Vector2 = _home + Vector2(65 if _patrol_right else -65, 0)
        if global_position.distance_to(destination) < 12.0:
            _patrol_right = not _patrol_right
        _walk_to(destination, walking_speed)
    queue_redraw()


func _walk_to(destination: Vector2, speed: float) -> void:
    velocity = global_position.direction_to(destination) * speed if global_position.distance_to(destination) > 8.0 else Vector2.ZERO
    move_and_slide()


func _draw() -> void:
    draw_circle(Vector2(0, 3), 22.0, Color("#1c2124", 0.42))
    draw_rect(Rect2(-18, -23, 36, 36), Color("#64727a"))
    draw_rect(Rect2(-13, -17, 26, 9), Color("#e96e5b") if state == &"pursue" else Color("#e2b96f"))
    draw_line(Vector2(-19, 1), Vector2(-29, 16), Color("#445158"), 5.0)
    draw_line(Vector2(19, 1), Vector2(28, 16), Color("#445158"), 5.0)
    draw_arc(Vector2.ZERO, 27, 0, float(durability) / float(max_durability) * TAU, 28, Color("#d8a37f"), 2.0)
