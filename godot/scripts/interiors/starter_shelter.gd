extends Node2D
## The Little Nest, NOT the future multi-level mesa refuge.
## Room geometry is provisional; first milestone proves space, light and exit.

signal transition_requested(destination: String)

const LightFactory = preload("res://scripts/presentation/light_factory.gd")
const EXIT_POSITION: Vector2 = Vector2(330, 443)

@onready var yuna: CharacterBody2D = $Yuna
@onready var workbench: Node2D = $Workbench
@onready var chest: Node2D = $StorageChest


func _ready() -> void:
    yuna.position = GameSession.shelter_position
    var camera: Camera2D = yuna.get_node("Camera2D") as Camera2D
    camera.zoom = Vector2(1.85, 1.85)
    camera.limit_left = 30
    camera.limit_top = 35
    camera.limit_right = 640
    camera.limit_bottom = 510
    var lamp := PointLight2D.new()
    lamp.position = Vector2(150, 225)
    lamp.texture = LightFactory.radial_texture()
    lamp.texture_scale = 3.5
    lamp.energy = 1.0
    lamp.color = Color("#ffc486")
    add_child(lamp)
    var shadow := LightOccluder2D.new()
    shadow.position = Vector2(485, 270)
    var shape := OccluderPolygon2D.new()
    shape.polygon = PackedVector2Array([
        Vector2(-36, -25), Vector2(36, -25),
        Vector2(36, 25), Vector2(-36, 25),
    ])
    shadow.occluder = shape
    add_child(shadow)
    # Provisional furniture should physically obstruct the player's feet.
    for footprint: Rect2 in [
        Rect2(105, 142, 100, 125), # bed
        Rect2(86, 340, 110, 55),  # cooker
        Rect2(443, 248, 110, 62), # workbench
        Rect2(460, 140, 74, 55),  # shelf
    ]:
        _add_furniture_collision(footprint)
    queue_redraw()


func _add_furniture_collision(footprint: Rect2) -> void:
    var body := StaticBody2D.new()
    body.position = footprint.get_center()
    var collider := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = footprint.size
    collider.shape = shape
    body.add_child(collider)
    add_child(body)


func _physics_process(_delta: float) -> void:
    yuna.position = yuna.position.clamp(Vector2(85, 120), Vector2(580, 455))


func _process(_delta: float) -> void:
    GameSession.shelter_position = yuna.position
    if Input.is_action_just_pressed("interact"):
        if yuna.position.distance_to(EXIT_POSITION) < 62.0:
            transition_requested.emit("outdoors")
        elif yuna.position.distance_to(chest.position) < 70.0:
            chest.call("interact", Input.is_action_pressed("sprint"))
            GameSession.save_to_disk()
        elif yuna.position.distance_to(workbench.position) < 92.0:
            workbench.call("interact")
            GameSession.save_to_disk()


func _draw() -> void:
    draw_rect(Rect2(30, 40, 610, 470), Color("#171414"))
    draw_rect(Rect2(66, 92, 545, 398), Color("#68513f"))
    # Patchwork sleeping corner.
    draw_rect(Rect2(105, 142, 100, 125), Color("#735344"))
    draw_rect(Rect2(115, 153, 80, 95), Color("#ae8d79"))
    draw_rect(Rect2(115, 158, 78, 35), Color("#d5bc99"))
    # Practical cooking plate and warm kitchen counter.
    draw_rect(Rect2(86, 340, 110, 55), Color("#514c43"))
    draw_circle(Vector2(150, 361), 17, Color("#b26e3d"))
    # Bench and shelf: Yuna's tools, not a futuristic command center.
    draw_rect(Rect2(443, 248, 110, 62), Color("#5c5c58"))
    draw_line(Vector2(459, 276), Vector2(535, 276), Color("#93a3a5"), 5.0)
    draw_rect(Rect2(460, 140, 74, 55), Color("#766655"))
    # A small beloved rug.
    draw_rect(Rect2(245, 314, 130, 83), Color("#996559"))
    draw_rect(Rect2(255, 325, 110, 60), Color("#b68c73"))
    # Hatch is a deliberate small room exit, not a map travel menu.
    draw_rect(Rect2(EXIT_POSITION - Vector2(34, 12), Vector2(68, 24)), Color("#332b2a"))
    draw_line(EXIT_POSITION - Vector2(34, 12), EXIT_POSITION + Vector2(34, -12), Color("#f6be73"), 3.0)
    draw_circle(Vector2(150, 225), 8, Color("#ffddaa"))
