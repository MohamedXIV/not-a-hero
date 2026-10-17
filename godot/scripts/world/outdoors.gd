extends Node2D
## One outdoors world position; WorldStreamer manages nearby authored scenery.

signal transition_requested(destination: String)

const HATCH_POSITION: Vector2 = Vector2(160.0, 330.0)

@onready var yuna: CharacterBody2D = $Yuna
@onready var ambient: CanvasModulate = $Ambient
@onready var streamer: Node2D = $WorldStreamer


func _ready() -> void:
    yuna.position = GameSession.outdoor_position
    var camera: Camera2D = yuna.get_node("Camera2D") as Camera2D
    camera.limit_left = 0
    camera.limit_top = 0
    camera.limit_right = 2560
    camera.limit_bottom = 640
    _sync_chunks()
    queue_redraw()


func _physics_process(_delta: float) -> void:
    yuna.position = yuna.position.clamp(Vector2(30, 42), Vector2(2530, 590))


func _process(_delta: float) -> void:
    GameSession.outdoor_position = yuna.position
    _sync_chunks()
    _apply_daylight()
    if Input.is_action_just_pressed("interact"):
        _try_interaction()
    if Input.is_action_just_pressed("mesa_repair"):
        _try_mesa_fuse()


func get_interaction_hint() -> String:
    if yuna.position.distance_to(HATCH_POSITION) < 55.0:
        return "E — Enter Little Nest"
    var closest: Node2D = _nearest_interactable()
    if closest != null:
        if closest.has_method("get_interaction_label"):
            return str(closest.call("get_interaction_label"))
        return "E — Inspect machine"
    return ""


func _try_interaction() -> void:
    if yuna.position.distance_to(HATCH_POSITION) < 55.0:
        transition_requested.emit("shelter")
        return
    var closest: Node2D = _nearest_interactable()
    if closest == null:
        return
    if closest.has_method("can_enter") and bool(closest.call("can_enter")):
        transition_requested.emit("mesa")
        return
    closest.call("interact")
    GameSession.save_to_disk()


func _try_mesa_fuse() -> void:
    # Q must target the same focused hatch as the visible E/Q prompt;
    # standing nearer to a manifold must not secretly change the door.
    var closest: Node2D = _nearest_interactable()
    if closest != null and closest.has_method("install_fuse") and bool(closest.call("install_fuse")):
        GameSession.save_to_disk()


func _nearest_interactable() -> Node2D:
    # One choice for the prompt and the actual E action. Overlapping
    # observations, salvage and the Mesa hatch must never pick the arbitrary
    # first node in the streamed group (which varies with chunk lifetime).
    var chosen: Node2D = null
    var smallest: float = 74.0
    var stable_path: String = ""
    for node: Node in get_tree().get_nodes_in_group("world_interactables"):
        if not (node is Node2D) or not node.is_inside_tree():
            continue
        if not node.has_method("interact"):
            continue
        var candidate: Node2D = node as Node2D
        var distance: float = yuna.global_position.distance_to(candidate.global_position)
        var path: String = str(candidate.get_path())
        if distance < smallest or (is_equal_approx(distance, smallest) and
                (stable_path.is_empty() or path < stable_path)):
            chosen = candidate
            smallest = distance
            stable_path = path
    return chosen


func _draw() -> void:
    draw_circle(HATCH_POSITION, 34.0, Color("#322922"))
    draw_arc(HATCH_POSITION, 31.0, 0.0, TAU, 28, Color("#eab66c"), 4.0)


func _sync_chunks() -> void:
    streamer.call("sync_for", yuna.position)


func _apply_daylight() -> void:
    var phase: float = GameSession.day_minutes / 1440.0
    var daylight: float = clampf((sin(phase * TAU - PI * 0.5) + 1.0) * 0.5, 0.08, 1.0)
    ambient.color = Color("#48535d").lerp(Color("#a5b4bb"), daylight)
