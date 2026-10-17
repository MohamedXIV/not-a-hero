extends Node2D
## A single, continuous 2D coordinate space with authored chunk scene lifecycle.
## This initial slice includes three fixed 640px chunks, not the whole world.

signal transition_requested(destination: String)

const CHUNK_WIDTH: float = 640.0
const HATCH_POSITION: Vector2 = Vector2(160.0, 330.0)
const CHUNKS: Array[PackedScene] = [
    preload("res://scenes/world/chunks/ash_flats.tscn"),
    preload("res://scenes/world/chunks/cable_edge.tscn"),
    preload("res://scenes/world/chunks/relay_waste.tscn"),
]

@onready var yuna: CharacterBody2D = $Yuna
@onready var ambient: CanvasModulate = $Ambient

var _loaded_chunks: Dictionary = {}


func _ready() -> void:
    yuna.position = GameSession.outdoor_position
    _sync_chunks()
    queue_redraw()


func _physics_process(_delta: float) -> void:
    yuna.position = yuna.position.clamp(Vector2(30, 42), Vector2(CHUNKS.size() * CHUNK_WIDTH - 30.0, 590))


func _process(_delta: float) -> void:
    GameSession.outdoor_position = yuna.position
    _sync_chunks()
    _apply_daylight()
    if yuna.position.distance_to(HATCH_POSITION) < 55.0 and Input.is_action_just_pressed("interact"):
        transition_requested.emit("shelter")


func _draw() -> void:
    draw_circle(HATCH_POSITION, 34.0, Color("#322922"))
    draw_arc(HATCH_POSITION, 31.0, 0.0, TAU, 28, Color("#eab66c"), 4.0)


func _sync_chunks() -> void:
    var index: int = clampi(int(floor(yuna.position.x / CHUNK_WIDTH)), 0, CHUNKS.size() - 1)
    for i: int in range(CHUNKS.size()):
        var nearby: bool = absi(i - index) <= 1
        if nearby and not _loaded_chunks.has(i):
            var chunk: Node2D = CHUNKS[i].instantiate() as Node2D
            chunk.position = Vector2(i * CHUNK_WIDTH, 0.0)
            chunk.z_index = -10
            add_child(chunk)
            _loaded_chunks[i] = chunk
        elif not nearby and _loaded_chunks.has(i):
            var old: Node2D = _loaded_chunks[i] as Node2D
            _loaded_chunks.erase(i)
            old.queue_free()


func _apply_daylight() -> void:
    var phase: float = GameSession.day_minutes / 1440.0
    var daylight: float = clampf((sin(phase * TAU - PI * 0.5) + 1.0) * 0.5, 0.08, 1.0)
    ambient.color = Color("#48535d").lerp(Color("#a5b4bb"), daylight)
