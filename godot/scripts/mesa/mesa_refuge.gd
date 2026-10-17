extends Node2D
## A partly habitable authored refuge. Utilities, growth and furniture are
## tangible local interactions; the service lift links a small lower gallery.
signal transition_requested(destination: String)

const LightFactory = preload("res://scripts/presentation/light_factory.gd")
const EXIT_POINT: Vector2 = Vector2(160, 595)
const SAFETY_PANEL: Vector2 = Vector2(700, 370)
const SUN_COURT: Vector2 = Vector2(785, 169)
const POWER_PANEL: Vector2 = Vector2(302, 328)
const FLOW_PANEL: Vector2 = Vector2(837, 355)
const REST_BENCH: Vector2 = Vector2(348, 467)
const WATER_FAUCET: Vector2 = Vector2(839, 461)
const COURT_CONTROL: Vector2 = Vector2(650, 260)
const GROWING_BED: Vector2 = Vector2(513, 449)

@onready var yuna: CharacterBody2D = $Yuna
@onready var ambient: CanvasModulate = $Ambient
@onready var decorator: Node2D = $ShelterDecorator
@onready var rear_nook: MesaRearNook = $RearNook
@onready var carrier_panel: MesaCarrierPanel = $CarrierPanel
@onready var depth_lift: MesaDepthLift = $DepthLift

var _court_light: PointLight2D
var _utility_light: PointLight2D
var _rear_barrier: StaticBody2D
var _last_court_ready: bool = false


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
    _utility_light = PointLight2D.new()
    _utility_light.position = Vector2(539, 397)
    _utility_light.texture = LightFactory.radial_texture()
    _utility_light.texture_scale = 5.3
    _utility_light.color = Color("#a2c7b6")
    add_child(_utility_light)
    _court_light = PointLight2D.new()
    _court_light.position = GROWING_BED
    _court_light.texture = LightFactory.radial_texture()
    _court_light.texture_scale = 2.3
    _court_light.color = Color("#bfd89f")
    add_child(_court_light)
    # The physical safety barrier lifts only when circulation is repaired.
    if not GameSession.mesa.flow_online():
        _rear_barrier = _add_collision(Rect2(956, 74, 36, 520))
    _add_collision(Rect2(910, 498, 86, 45))
    _refresh_visuals()
    _last_court_ready = GameSession.mesa.court_ready
    depth_lift.enter_requested.connect(_enter_depth)
    if not GameSession.mesa.first_sector_safe:
        GameSession.report("A whole place... but something's still running. Keep it safe, Yuna.")


func _add_collision(rect: Rect2) -> StaticBody2D:
    var body := StaticBody2D.new()
    body.position = rect.get_center()
    var collider := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = rect.size
    collider.shape = shape
    body.add_child(collider)
    add_child(body)
    return body


func _physics_process(_delta: float) -> void:
    yuna.position = yuna.position.clamp(Vector2(84, 103), Vector2(1185, 659))


func _process(_delta: float) -> void:
    GameSession.mesa_position = yuna.position
    if _last_court_ready != GameSession.mesa.court_ready:
        _last_court_ready = GameSession.mesa.court_ready
        queue_redraw()
    if Input.is_action_just_pressed("interact") and not decorator.edit_mode:
        _interact_nearby()
    if Input.is_action_just_pressed("mesa_repair") and not decorator.edit_mode:
        _use_spare_part()


func _interaction_target() -> String:
    # The closest station always owns BOTH the visible E prompt and the action,
    # especially around the lift/acoustic screen and cot/service carrier.
    # Never let a wider-radius station steal the player's nearer choice.
    var sites: Array[Dictionary] = [
        {"id": "exit", "point": EXIT_POINT, "range": 68.0},
        {"id": "safety", "point": SAFETY_PANEL, "range": 75.0},
        {"id": "power", "point": POWER_PANEL, "range": 62.0},
        {"id": "flow", "point": FLOW_PANEL, "range": 60.0},
        {"id": "court", "point": COURT_CONTROL, "range": 57.0},
        {"id": "greens", "point": GROWING_BED, "range": 57.0},
        {"id": "water", "point": WATER_FAUCET, "range": 52.0},
        {"id": "bench", "point": REST_BENCH, "range": 62.0},
        {"id": "lift", "point": depth_lift.position, "range": MesaDepthLift.RADIUS},
        {"id": "carrier", "point": carrier_panel.position, "range": MesaCarrierPanel.INTERACT_RADIUS},
        {"id": "nook", "point": MesaRearNook.PANEL_POINT, "range": MesaRearNook.PANEL_RADIUS},
        {"id": "nook", "point": MesaRearNook.REST_POINT, "range": MesaRearNook.REST_RADIUS},
    ]
    var selected: String = ""
    var nearest: float = INF
    for site: Dictionary in sites:
        var distance: float = yuna.position.distance_to(site["point"] as Vector2)
        if distance < float(site["range"]) and distance < nearest:
            nearest = distance
            selected = String(site["id"])
    return selected


func get_interaction_hint() -> String:
    if decorator.edit_mode:
        return str(decorator.call("hint"))
    match _interaction_target():
        "exit":
            return "E — Return outside (Little Nest remains home)"
        "safety":
            return ("E — Check safe sector controls" if GameSession.mesa.first_sector_safe
                    else "E — Isolate dangerous power / secure first room")
        "power":
            if not GameSession.mesa.first_sector_safe:
                return "Isolate the first room before servicing live power."
            return ("Main power restored" if GameSession.mesa.power_online()
                    else "E — Hand-start power (%d/2) | Q — Use capacitor" % GameSession.mesa.power_progress)
        "flow":
            if not GameSession.mesa.power_online():
                return "Circulation needs power first."
            return ("Coolant circulation stable" if GameSession.mesa.flow_online()
                    else "E — Manually purge loop (%d/2) | Q — Use filter" % GameSession.mesa.flow_progress)
        "court":
            if not GameSession.mesa.flow_online():
                return "Sun court irrigation: restore the coolant loop first."
            return ("The sun court is alive" if GameSession.mesa.court_restored()
                    else "E — Rebuild growing-court valves (%d/2)" % GameSession.mesa.court_progress)
        "greens":
            if not GameSession.mesa.court_restored():
                return "The old root bed needs clean circulation."
            return ("E — Eat fresh courtyard greens" if GameSession.mesa.court_ready
                    else "Young shoots growing in natural light")
        "water":
            return "E — Drink clean water" if GameSession.mesa.flow_online() else "Water tap: no clean flow yet."
        "bench":
            return "E — Rest on the recovered bench" if GameSession.mesa.power_online() else "Bench: too cold and dark to settle yet."
        "lift":
            return depth_lift.hint_at(yuna.global_position)
        "carrier":
            return carrier_panel.hint_at(yuna.global_position)
        "nook":
            return rear_nook.hint_at(yuna.position)
    return "A shaft of sunlight. " + str(decorator.call("hint"))


func _interact_nearby() -> void:
    var target: String = _interaction_target()
    if target == "lift":
        depth_lift.interact_at(yuna.global_position)
        return
    if target == "carrier":
        carrier_panel.interact_at(yuna.global_position)
        return
    if target == "nook":
        rear_nook.interact_at(yuna.position)
        return
    if target == "exit":
        # Always emerge beside the discovered exterior doorway.
        GameSession.outdoor_position = Vector2(2420, 172)
        transition_requested.emit("outdoors")
    elif target == "safety":
        if GameSession.mesa.make_first_sector_safe():
            GameSession.speak(&"mesa_first_safe")
            GameSession.report("That room is yours to breathe in, Yuna. The rest can wait.")
            _refresh_visuals()
            GameSession.save_to_disk()
        else:
            GameSession.report("First sector stabilized. The deeper facility still needs work.")
    elif target == "power":
        if GameSession.mesa.work_power():
            GameSession.advance_time(MesaState.WORK_MINUTES)
            _refresh_visuals()
            GameSession.report("The main bus is live." if GameSession.mesa.power_online()
                    else "One cam released. Take your time, Yuna.")
            if GameSession.mesa.power_online():
                GameSession.speak(&"mesa_power_restored")
            GameSession.save_to_disk()
        else:
            GameSession.report("Secure the first room before touching the power bus.")
    elif target == "flow":
        if GameSession.mesa.work_flow():
            GameSession.advance_time(MesaState.WORK_MINUTES)
            _refresh_visuals()
            GameSession.report("Clean circulation. The rear lock releases." if GameSession.mesa.flow_online()
                    else "First purge complete. Still some pressure in the lines.")
            if GameSession.mesa.flow_online():
                GameSession.speak(&"mesa_flow_restored")
            GameSession.save_to_disk()
        else:
            GameSession.report("The pumps need working power first, Yuna.")
    elif target == "court":
        if GameSession.mesa.restore_court_stage():
            GameSession.advance_time(MesaState.WORK_MINUTES)
            _refresh_visuals()
            if GameSession.mesa.court_restored():
                GameSession.speak(&"mesa_court_restored")
                GameSession.report("Old valves breathe again. The sun court can grow.")
            else:
                GameSession.report("First valve turned. The second one will open the bed.")
            GameSession.save_to_disk()
        else:
            GameSession.report("The growing court needs clean circulation first.")
    elif target == "greens":
        if GameSession.mesa.harvest_court(GameSession.condition):
            _refresh_visuals()
            GameSession.speak(&"mesa_greens")
            GameSession.report("Fresh greens. Nothing to carry, just a quiet meal.")
            GameSession.save_to_disk()
        else:
            GameSession.report("Let the roots grow, or save the greens until you're hungry.")
    elif target == "water":
        if GameSession.mesa.flow_online() and GameSession.condition.drink_water():
            GameSession.report("Clean water, from a place you repaired yourself.")
            GameSession.save_to_disk()
        else:
            GameSession.report("The tap is dry, or you're not thirsty.")
    elif target == "bench":
        if GameSession.mesa.power_online():
            GameSession.sleep_at_home()
            _refresh_visuals()
            GameSession.report("The mesa is quiet enough to rest now, Yuna.")
            GameSession.save_to_disk()
        else:
            GameSession.report("It's still too cold and dark to stay here.")


func _enter_depth() -> void:
    GameSession.mesa_position = Vector2(1110, 264)
    transition_requested.emit("mesa_depth")


func _use_spare_part() -> void:
    var target: String = _interaction_target()
    if target == "power":
        if GameSession.mesa.replace_power_coupler(GameSession.bag):
            _refresh_visuals()
            GameSession.speak(&"mesa_power_restored")
            GameSession.report("That spare capacitor woke the main bus.")
            GameSession.save_to_disk()
        else:
            GameSession.report("A capacitor would help. The manual start still works.")
    elif target == "flow":
        if GameSession.mesa.replace_flow_filter(GameSession.bag):
            _refresh_visuals()
            GameSession.speak(&"mesa_flow_restored")
            GameSession.report("Fresh filter seated. The rear lock releases.")
            GameSession.save_to_disk()
        else:
            GameSession.report("No spare filter. You can manually purge the line.")


func _refresh_visuals() -> void:
    ambient.color = (Color("#898477") if GameSession.mesa.power_online()
            else Color("#68615b") if GameSession.mesa.first_sector_safe else Color("#354653"))
    if _utility_light != null:
        _utility_light.energy = 0.9 if GameSession.mesa.power_online() else 0.0
    if _court_light != null:
        _court_light.energy = 0.65 if GameSession.mesa.court_restored() else 0.0
    if GameSession.mesa.flow_online() and is_instance_valid(_rear_barrier):
        remove_child(_rear_barrier)
        _rear_barrier.queue_free()
        _rear_barrier = null
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
    draw_rect(Rect2(387, 393, 185, 120),
        Color("#536e4e") if GameSession.mesa.court_restored() else Color("#6b775e"))
    for i: int in range(5):
        var root: Vector2 = Vector2(406 + i * 35, 442)
        if GameSession.mesa.court_restored():
            draw_line(root, root + Vector2(0, -16), Color("#91c68e"), 3.0)
            draw_circle(root + Vector2(-6, -17), 7.0, Color("#80b87b"))
            if GameSession.mesa.court_ready:
                draw_circle(root + Vector2(6, -24), 10.0, Color("#c9de8f"))
        else:
            draw_line(root - Vector2(7, 0), root + Vector2(8, 0), Color("#554a40"), 3.0)
    draw_rect(Rect2(COURT_CONTROL - Vector2(19, 14), Vector2(38, 28)),
        Color("#6aa889") if GameSession.mesa.court_restored() else Color("#4b5254"))
    draw_circle(COURT_CONTROL, 6.0, Color("#c6eaba") if GameSession.mesa.court_restored()
        else Color("#c38b69"))
    draw_rect(Rect2(615, 322, 167, 103), Color("#464a50"))
    draw_rect(Rect2(648, 341, 104, 63), Color("#819198"))
    draw_circle(SAFETY_PANEL, 11, Color("#8fd4ba") if GameSession.mesa.first_sector_safe else Color("#de895e"))
    # Reveals a genuinely reachable rear machine gallery after circulation repair.
    draw_rect(Rect2(963, 100, 212, 475),
        Color("#5d756e") if GameSession.mesa.flow_online() else Color("#242b35"))
    for y: int in range(100, 555, 39):
        draw_line(Vector2(962, y), Vector2(1171, y), Color("#715452"), 3)
    if not GameSession.mesa.flow_online():
        draw_line(Vector2(973, 100), Vector2(973, 571), Color("#e5a26a"), 8)
    else:
        for channel: int in range(3):
            draw_line(Vector2(1016 + channel * 54, 136), Vector2(1016 + channel * 54, 528),
                Color("#a0cfc8"), 8)
    draw_rect(Rect2(POWER_PANEL - Vector2(24, 20), Vector2(48, 40)),
        Color("#668e80") if GameSession.mesa.power_online() else Color("#454a4d"))
    draw_circle(POWER_PANEL, 10, Color("#abdf9a") if GameSession.mesa.power_online() else Color("#bd8368"))
    draw_rect(Rect2(FLOW_PANEL - Vector2(26, 22), Vector2(52, 44)),
        Color("#518b94") if GameSession.mesa.flow_online() else Color("#3c4d53"))
    draw_circle(FLOW_PANEL, 11, Color("#c0f0df") if GameSession.mesa.flow_online() else Color("#c38d73"))
    draw_rect(Rect2(REST_BENCH - Vector2(42, 16), Vector2(84, 31)), Color("#8c806a"))
    draw_rect(Rect2(WATER_FAUCET - Vector2(18, 11), Vector2(36, 22)),
        Color("#81bec8") if GameSession.mesa.flow_online() else Color("#505c60"))
    # Welcoming escape/return hatch, never an irreversible story transition.
    draw_rect(Rect2(EXIT_POINT - Vector2(52, 16), Vector2(104, 40)), Color("#2c3739"))
    draw_line(EXIT_POINT + Vector2(-48, -12), EXIT_POINT + Vector2(48, -12), Color("#e8c48b"), 4)
    if GameSession.mesa.first_sector_safe:
        draw_circle(Vector2(312, 458), 21, Color("#f4d79f"))
        draw_line(Vector2(357, 545), Vector2(603, 545), Color("#e7a875"), 5)
