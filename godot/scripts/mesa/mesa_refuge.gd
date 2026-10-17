extends Node2D
## P4a: the mesa is a real, larger interior, initially dark and only partly
## habitable. The first sector can be made safe; other systems remain shut.
signal transition_requested(destination: String)

const LightFactory = preload("res://scripts/presentation/light_factory.gd")
const EXIT_POINT: Vector2 = Vector2(160, 595)
const SAFETY_PANEL: Vector2 = Vector2(700, 370)
const SUN_COURT: Vector2 = Vector2(785, 169)

@onready var yuna: CharacterBody2D = $Yuna
@onready var ambient: CanvasModulate = $Ambient


func _ready() -> void:
    yuna.position = GameSession.mesa_position
    var camera: Camera2D = yuna.get_node("Camera2D") as Camera2D
    camera.zoom = Vector2(1.35, 1.35)
    camera.limit_left = 0
    camera.limit_top = 0
    camera.limit_right = 1280
    camera.limit_bottom = 730
    var daylight := PointLight2D.new()
    daylight.position = SUN_COURT
    daylight.texture = LightFactory.radial_texture()
    daylight.texture_scale = 5.0
    daylight.energy = 0.85
    daylight.color = Color("#eccb97")
    add_child(daylight)
    var emergency := PointLight2D.new()
    emergency.position = Vector2(340, 496)
    emergency.texture = LightFactory.radial_texture()
    emergency.texture_scale = 2.7
    emergency.energy = 0.55
    emergency.color = Color("#b3b9c5")
    add_child(emergency)
    # Closed high-voltage rear sector stays physically inaccessible until P4b.
    _add_collision(Rect2(956, 74, 36, 520))
    _add_collision(Rect2(910, 498, 86, 45))
    _refresh_visuals()
    if not GameSession.mesa.first_sector_safe:
        GameSession.report("A whole place... but something's still running. Keep it safe, Yuna.")


func _add_collision(rect: Rect2) -> void:
    var body := StaticBody2D.new()
    body.position = rect.get_center()
    var collider := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = rect.size
    collider.shape = shape
    body.add_child(collider)
    add_child(body)


func _physics_process(_delta: float) -> void:
    yuna.position = yuna.position.clamp(Vector2(84, 103), Vector2(1185, 659))


func _process(_delta: float) -> void:
    GameSession.mesa_position = yuna.position
    if Input.is_action_just_pressed("interact"):
        _interact_nearby()


func get_interaction_hint() -> String:
    if yuna.position.distance_to(EXIT_POINT) < 68.0:
        return "E — Return outside (Little Nest remains home)"
    if yuna.position.distance_to(SAFETY_PANEL) < 75.0:
        return ("E — Check safe sector controls" if GameSession.mesa.first_sector_safe
                else "E — Isolate dangerous power / secure first room")
    return "A shaft of real sunlight... and rooms still sealed."


func _interact_nearby() -> void:
    if yuna.position.distance_to(EXIT_POINT) < 68.0:
        # Always emerge beside the discovered exterior doorway.
        GameSession.outdoor_position = Vector2(2420, 172)
        transition_requested.emit("outdoors")
    elif yuna.position.distance_to(SAFETY_PANEL) < 75.0:
        if GameSession.mesa.make_first_sector_safe():
            GameSession.speak(&"mesa_first_safe")
            GameSession.report("That room is yours to breathe in, Yuna. The rest can wait.")
            _refresh_visuals()
            GameSession.save_to_disk()
        else:
            GameSession.report("First sector stabilized. The deeper facility still needs work.")


func _refresh_visuals() -> void:
    ambient.color = Color("#68615b") if GameSession.mesa.first_sector_safe else Color("#354653")
    queue_redraw()


func _draw() -> void:
    # Temporary machine-built facility: sun court, living/work areas, distant
    # sealed equipment chambers. No human-world city architecture.
    draw_rect(Rect2(20, 20, 1230, 690), Color("#121b21"))
    draw_rect(Rect2(72, 80, 1120, 575), Color("#455057"))
    for ix: int in range(0, 14):
        draw_line(Vector2(95 + ix * 82, 83), Vector2(95 + ix * 82, 645), Color("#2b3a3c", 0.5), 2)
    for iy: int in range(0, 7):
        draw_line(Vector2(72, 99 + iy * 84), Vector2(1190, 99 + iy * 84), Color("#28353a", 0.5), 2)
    # Architectural daylight access from a protected shaft.
    draw_circle(SUN_COURT, 146, Color("#52616c"))
    draw_circle(SUN_COURT, 117, Color("#d6bd8b"))
    draw_circle(SUN_COURT, 89, Color("#e9d6af"))
    for x: int in [696, 792, 885]:
        draw_line(Vector2(x, 75), Vector2(x, 262), Color("#515b60"), 8)
    # Tangible but unpowered growing court and engineering platforms.
    draw_rect(Rect2(360, 365, 245, 182), Color("#3b5452"))
    draw_rect(Rect2(387, 393, 185, 120), Color("#6b775e"))
    draw_rect(Rect2(615, 322, 167, 103), Color("#464a50"))
    draw_rect(Rect2(648, 341, 104, 63), Color("#819198"))
    draw_circle(SAFETY_PANEL, 11, Color("#8fd4ba") if GameSession.mesa.first_sector_safe else Color("#de895e"))
    # Unsecured rear chambers are physically fenced off for later restoration.
    draw_rect(Rect2(963, 100, 212, 475), Color("#242b35"))
    for y: int in range(100, 555, 39):
        draw_line(Vector2(962, y), Vector2(1171, y), Color("#715452"), 3)
    draw_line(Vector2(973, 100), Vector2(973, 571), Color("#e5a26a"), 8)
    # Welcoming escape/return hatch, never an irreversible story transition.
    draw_rect(Rect2(EXIT_POINT - Vector2(52, 16), Vector2(104, 40)), Color("#2c3739"))
    draw_line(EXIT_POINT + Vector2(-48, -12), EXIT_POINT + Vector2(48, -12), Color("#e8c48b"), 4)
    if GameSession.mesa.first_sector_safe:
        draw_circle(Vector2(312, 458), 21, Color("#f4d79f"))
        draw_line(Vector2(357, 545), Vector2(603, 545), Color("#e7a875"), 5)
