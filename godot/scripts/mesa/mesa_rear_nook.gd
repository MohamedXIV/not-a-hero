class_name MesaRearNook
extends Node2D
## The rear gallery's first intimate space: a reused acoustic partition,
## a practical resting cot and a first chosen night. No relocation menu.
## This scene owns its presentation and local E actions; MesaState owns facts.

const LightFactory = preload("res://scripts/presentation/light_factory.gd")
const PANEL_POINT: Vector2 = Vector2(1078, 185)
const REST_POINT: Vector2 = Vector2(1076, 432)
const PANEL_RADIUS: float = 53.0
const REST_RADIUS: float = 63.0
const NOOK_WORK_MINUTES: float = 25.0

var _warm_light: PointLight2D
var _cot_body: StaticBody2D


func _ready() -> void:
    _warm_light = PointLight2D.new()
    _warm_light.position = Vector2(1120, 380)
    _warm_light.texture = LightFactory.radial_texture()
    _warm_light.texture_scale = 2.2
    _warm_light.color = Color("#efbd8d")
    add_child(_warm_light)
    if GameSession.mesa.rear_nook_prepared:
        _install_cot_collision()
    _refresh()


func hint_at(player_position: Vector2) -> String:
    if player_position.distance_to(PANEL_POINT) < PANEL_RADIUS:
        if not GameSession.mesa.flow_online():
            return "Old sound baffles: the rear gallery is sealed."
        return ("Acoustic screen secured — you made this corner quiet."
                if GameSession.mesa.rear_nook_prepared
                else "E — Pull down the old acoustic screen (no parts)")
    if player_position.distance_to(REST_POINT) < REST_RADIUS:
        if not GameSession.mesa.rear_nook_prepared:
            return "Bare old steel. Maybe the service screen could shelter it."
        if not GameSession.mesa.first_night_spent and GameSession.mesa.court_restored():
            return "E — Spend a first night beside the growing court"
        return "E — Rest in your new quiet corner"
    return ""


func interact_at(player_position: Vector2) -> bool:
    if player_position.distance_to(PANEL_POINT) < PANEL_RADIUS:
        if GameSession.mesa.prepare_rear_nook():
            GameSession.advance_time(NOOK_WORK_MINUTES)
            _install_cot_collision()
            _refresh()
            GameSession.speak(&"mesa_rear_nook")
            GameSession.report("The old screen holds. No alarms, just a quieter corner.")
            GameSession.save_to_disk()
        else:
            GameSession.report("The rear passage needs circulating water, or this screen is already secure.")
        return true

    if player_position.distance_to(REST_POINT) < REST_RADIUS:
        if not GameSession.mesa.rear_nook_prepared:
            GameSession.report("Not somewhere you can rest yet.")
            return true
        var first_night: bool = GameSession.mesa.settle_first_night()
        # Before the garden grows, the prepared cot is still a reliable bed.
        # No decorative-object gate, story prompt, calendar deadline or locked home.
        GameSession.sleep_at_home()
        if first_night:
            _refresh()
            GameSession.speak(&"mesa_first_night")
            GameSession.report("You stayed. Little Nest is still yours. This place can be, too.")
        else:
            GameSession.report("The new corner is quiet enough to sleep, Yuna.")
        GameSession.save_to_disk()
        return true
    return false


func _install_cot_collision() -> void:
    if is_instance_valid(_cot_body):
        return
    _cot_body = StaticBody2D.new()
    _cot_body.position = Vector2(1140, 396)
    var collision := CollisionShape2D.new()
    var footprint := RectangleShape2D.new()
    footprint.size = Vector2(56, 72)
    collision.shape = footprint
    _cot_body.add_child(collision)
    add_child(_cot_body)


func _refresh() -> void:
    if is_instance_valid(_warm_light):
        _warm_light.energy = (0.86 if GameSession.mesa.first_night_spent else 0.55
                if GameSession.mesa.rear_nook_prepared else 0.0)
    queue_redraw()


func _draw() -> void:
    # Temporary authored forms until P5 art selection: the player should
    # visually recognize a *changed* living space, not a generic repair flag.
    draw_rect(Rect2(PANEL_POINT - Vector2(20, 15), Vector2(40, 30)), Color("#4b6264"))
    draw_circle(PANEL_POINT, 7.0, Color("#f4d49d")
        if GameSession.mesa.rear_nook_prepared else Color("#c98271"))
    if not GameSession.mesa.rear_nook_prepared:
        draw_rect(Rect2(1031, 300, 136, 169), Color("#333f43", 0.67))
        for index: int in range(3):
            draw_line(Vector2(1036, 312 + index * 45), Vector2(1161, 312 + index * 45),
                Color("#68717a"), 6.0)
        return

    draw_rect(Rect2(1025, 302, 144, 170), Color("#726e61", 0.83))
    draw_rect(Rect2(1037, 313, 125, 151), Color("#9d9375", 0.31))
    draw_line(Vector2(1033, 310), Vector2(1033, 462), Color("#d6a87e"), 6.0)
    draw_line(Vector2(1033, 311), Vector2(1161, 311), Color("#c49d78"), 5.0)
    # Cot: solid physical footprint placed along the right wall so a left
    # walking lane into the gallery remains open.
    draw_rect(Rect2(1112, 360, 56, 72), Color("#66554c"))
    draw_rect(Rect2(1119, 368, 43, 56), Color("#c4ab8d"))
    draw_rect(Rect2(1121, 370, 39, 19), Color("#e4d2ad"))
    if GameSession.mesa.first_night_spent:
        # A tiny deliberately placed personal cloth and a repaired warm lamp
        # distinguish spending one night from merely powering the facility.
        draw_rect(Rect2(1120, 390, 39, 22), Color("#a66f66"))
        draw_line(Vector2(1118, 410), Vector2(1159, 410), Color("#ecc39c"), 2.0)
        draw_circle(Vector2(1097, 366), 9, Color("#c49b6d"))
        draw_circle(Vector2(1097, 366), 4, Color("#ffe0a4"))
