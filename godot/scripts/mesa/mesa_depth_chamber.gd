extends Node2D
## A hand-authored lower gallery, not a dungeon or a solved civilization myth.
## Warmth is a reversible environmental choice, no loot faucet or boss.
signal transition_requested(destination: String)

const LightFactory = preload("res://scripts/presentation/light_factory.gd")
const EXIT_POINT: Vector2 = Vector2(125, 493)
const ARCHIVE_POINT: Vector2 = Vector2(590, 344)
const REGULATOR_POINT: Vector2 = Vector2(415, 390)
const REST_POINT: Vector2 = Vector2(632, 440)
const RADIUS: float = 62.0
const SERVICE_MINUTES: float = 20.0

@onready var yuna: CharacterBody2D = $Yuna
@onready var ambient: CanvasModulate = $Ambient
var _interact_held: bool = false
var _cradle_light: PointLight2D
var _utility_light: PointLight2D


func _ready() -> void:
    yuna.position = GameSession.mesa_depth_position
    var camera: Camera2D = yuna.get_node("Camera2D") as Camera2D
    camera.zoom = Vector2(1.4, 1.4)
    camera.limit_left = 0
    camera.limit_top = 0
    camera.limit_right = 800
    camera.limit_bottom = 590
    _utility_light = PointLight2D.new()
    _utility_light.position = Vector2(218, 405)
    _utility_light.texture = LightFactory.radial_texture()
    _utility_light.texture_scale = 4.2
    _utility_light.energy = 0.58
    _utility_light.color = Color("#91bbc4")
    add_child(_utility_light)
    _cradle_light = PointLight2D.new()
    _cradle_light.position = Vector2(601, 250)
    _cradle_light.texture = LightFactory.radial_texture()
    _cradle_light.texture_scale = 3.4
    _cradle_light.color = Color("#edb48e")
    add_child(_cradle_light)
    # Service walls and a real solid protected cradle, not a fake backdrop.
    _add_collision(Rect2(488, 138, 244, 178))
    _add_collision(Rect2(309, 140, 82, 60))
    _refresh()


func _add_collision(rect: Rect2) -> void:
    var body := StaticBody2D.new()
    body.position = rect.get_center()
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = rect.size
    collision.shape = shape
    body.add_child(collision)
    add_child(body)


func _physics_process(_delta: float) -> void:
    yuna.position = yuna.position.clamp(Vector2(65, 67), Vector2(736, 515))


func _process(_delta: float) -> void:
    GameSession.mesa_depth_position = yuna.position
    if not Input.is_action_pressed("interact"):
        _interact_held = false
    if Input.is_action_just_pressed("interact") and not _interact_held:
        _interact_held = true
        _interact_nearby()


func get_interaction_hint() -> String:
    if yuna.position.distance_to(EXIT_POINT) < RADIUS:
        return "E — Take the service lift back to the sun court"
    if yuna.position.distance_to(ARCHIVE_POINT) < RADIUS:
        return ("E — Re-examine the empty thermal cradle"
                if GameSession.mesa.depth_archive_read else "E — Examine preserved temperature log")
    if yuna.position.distance_to(REGULATOR_POINT) < RADIUS:
        if not GameSession.mesa.depth_archive_read:
            return "Thermal manifold — read the preserved log before changing the flow."
        return ("E — Let the cradle cool (reversible)"
                if GameSession.mesa.depth_warm else "E — Restore the cradle's gentle warmth")
    if yuna.position.distance_to(REST_POINT) < RADIUS:
        return ("E — Sit and rest beside the warm cradle"
                if GameSession.mesa.depth_warm else "The alcove is cold; restore its gentle heat first.")
    return ""


func _interact_nearby() -> void:
    if yuna.position.distance_to(EXIT_POINT) < RADIUS:
        GameSession.mesa_position = Vector2(1110, 264)
        transition_requested.emit("mesa")
        return
    if yuna.position.distance_to(ARCHIVE_POINT) < RADIUS:
        if GameSession.mesa.read_depth_archive():
            GameSession.notebook.discover("mesa_thermal_archive")
            GameSession.speak(&"mesa_thermal_archive")
            GameSession.report("It kept a space warm. An empty space. Who was it waiting for?")
            GameSession.save_to_disk()
        else:
            GameSession.report("Temperature records, but no name, sender or answer.")
    elif yuna.position.distance_to(REGULATOR_POINT) < RADIUS:
        if not GameSession.mesa.depth_archive_read:
            GameSession.report("Read the archived thermal range before touching the regulator.")
            return
        if GameSession.mesa.set_depth_warmth():
            GameSession.advance_time(SERVICE_MINUTES)
            _refresh()
            if GameSession.mesa.depth_warm:
                GameSession.speak(&"mesa_depth_warm")
                GameSession.report("The machine warms an empty cradle. You chose to keep it gentle.")
            else:
                GameSession.report("The loop rests in standby. You can turn it on again.")
            GameSession.save_to_disk()
    elif yuna.position.distance_to(REST_POINT) < RADIUS:
        if GameSession.mesa.depth_warm:
            GameSession.sleep_at_home()
            GameSession.report("It's safe to stay quiet here, Yuna.")
            GameSession.save_to_disk()
        else:
            GameSession.report("A cold machine enclosure isn't somewhere to rest yet.")


func _refresh() -> void:
    if is_instance_valid(_cradle_light):
        _cradle_light.energy = 1.1 if GameSession.mesa.depth_warm else 0.0
    queue_redraw()


func _draw() -> void:
    draw_rect(Rect2(24, 24, 744, 542), Color("#18252e"))
    draw_rect(Rect2(52, 79, 691, 453), Color("#43545a"))
    for line_y: int in range(123, 529, 60):
        draw_line(Vector2(65, line_y), Vector2(728, line_y), Color("#2b4146", 0.7), 3.0)
    draw_line(Vector2(89, 105), Vector2(695, 105), Color("#819c9b"), 7.0)
    draw_rect(Rect2(488, 138, 244, 178), Color("#334549"))
    draw_rect(Rect2(516, 158, 190, 122),
        Color("#a17d68") if GameSession.mesa.depth_warm else Color("#62747b"))
    draw_rect(Rect2(536, 173, 147, 90), Color("#e8c9a6", 0.75)
        if GameSession.mesa.depth_warm else Color("#263941"))
    # Intentionally empty climate cradle: no human remains, baby, plant or
    # dictated identity. Who built this and what was here remain unknown.
    draw_arc(Vector2(608, 218), 48, 0.0, TAU, 40,
        Color("#edcba5") if GameSession.mesa.depth_warm else Color("#90a5aa"), 6.0)
    # The visible log terminal is OUTSIDE the protected enclosure. Yuna
    # needs to approach it rather than magically occupying its solid interior.
    draw_rect(Rect2(ARCHIVE_POINT - Vector2(25, 15), Vector2(50, 30)), Color("#314b51"))
    draw_circle(ARCHIVE_POINT, 10, Color("#b0cbd3"))
    draw_rect(Rect2(REGULATOR_POINT - Vector2(35, 23), Vector2(70, 46)),
        Color("#335960"))
    draw_circle(REGULATOR_POINT, 12,
        Color("#ebbd86") if GameSession.mesa.depth_warm else Color("#8aacae"))
    draw_rect(Rect2(590, 425, 91, 31),
        Color("#9c8170") if GameSession.mesa.depth_warm else Color("#556066"))
    draw_rect(Rect2(EXIT_POINT - Vector2(48, 16), Vector2(96, 42)), Color("#202f33"))
    draw_line(EXIT_POINT + Vector2(-44, -14), EXIT_POINT + Vector2(44, -14), Color("#e1bc8a"), 5.0)
