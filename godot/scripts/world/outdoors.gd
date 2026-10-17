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
    camera.limit_right = 1920
    camera.limit_bottom = 640
    _sync_chunks()
    queue_redraw()


func _physics_process(_delta: float) -> void:
    yuna.position = yuna.position.clamp(Vector2(30, 42), Vector2(1890, 590))


func _process(_delta: float) -> void:
    GameSession.outdoor_position = yuna.position
    _sync_chunks()
    _apply_daylight()
    if Input.is_action_just_pressed("interact"):
        _try_interaction()


func get_interaction_hint() -> String:
    if yuna.position.distance_to(HATCH_POSITION) < 55.0:
        return "E — Enter Little Nest"
    for node: Node in get_tree().get_nodes_in_group("world_interactables"):
        if node is Node2D and yuna.global_position.distance_to((node as Node2D).global_position) < 74.0:
            if node.has_method("get_interaction_label"):
                return str(node.call("get_interaction_label"))
            return "E — Inspect machine"
    return ""


func _try_interaction() -> void:
    if yuna.position.distance_to(HATCH_POSITION) < 55.0:
        transition_requested.emit("shelter")
        return
    for node: Node in get_tree().get_nodes_in_group("world_interactables"):
        if node is Node2D and yuna.global_position.distance_to((node as Node2D).global_position) < 74.0:
            node.call("interact")
            GameSession.save_to_disk()
            return


func _draw() -> void:
    draw_circle(HATCH_POSITION, 34.0, Color("#322922"))
    draw_arc(HATCH_POSITION, 31.0, 0.0, TAU, 28, Color("#eab66c"), 4.0)


func _sync_chunks() -> void:
    streamer.call("sync_for", yuna.position)


func _apply_daylight() -> void:
    var phase: float = GameSession.day_minutes / 1440.0
    var daylight: float = clampf((sin(phase * TAU - PI * 0.5) + 1.0) * 0.5, 0.08, 1.0)
    ambient.color = Color("#48535d").lerp(Color("#a5b4bb"), daylight)
