extends Node
## P4c end-to-end: actual E at court valves and growing bed, usable G
## decoration space, physical lamps, and both-home FileAccess re-entry.

const TEST_SAVE: String = "user://nah_p4c_court_test.json"
var _had_save: bool = false
var _player_bytes: PackedByteArray


func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    _had_save = FileAccess.file_exists(GameSession.SAVE_PATH)
    if _had_save:
        _player_bytes = FileAccess.get_file_as_bytes(GameSession.SAVE_PATH)
    GameSession.mesa = MesaState.new()
    GameSession.mesa.examine()
    for i: int in range(3):
        GameSession.mesa.turn_handwheel()
    GameSession.mesa.make_first_sector_safe()
    GameSession.mesa.work_power()
    GameSession.mesa.work_power()
    GameSession.current_level = "mesa"
    GameSession.mesa_position = Vector2(510, 552)
    GameSession.bag = InventoryState.new()
    GameSession.decor = ShelterDecorState.new()
    GameSession.mesa_decor = ShelterDecorState.new(true)
    GameSession.condition = YunaCondition.new()
    if not GameSession.decor.place("rug", Vector2(448, 384)):
        _fail("Little Nest fixture not prepared")
        return
    if not GameSession.bag.try_receive({"rug": 1, "lantern": 1}):
        _fail("Decor inventory not prepared")
        return

    var scene: PackedScene = load("res://scenes/interiors/mesa_refuge.tscn") as PackedScene
    var room: Node2D = scene.instantiate() as Node2D
    add_child(room)
    var yuna: CharacterBody2D = room.get_node("Yuna") as CharacterBody2D
    var decor: Node2D = room.get_node("ShelterDecorator") as Node2D
    yuna.position = room.COURT_CONTROL
    await get_tree().process_frame
    if not str(room.call("get_interaction_hint")).contains("coolant loop"):
        _fail("Court incorrectly repairable before circulation")
        return
    await _tap(KEY_E)
    if GameSession.mesa.court_progress != 0:
        _fail("Blocked court E advanced before coolant repair")
        return
    GameSession.mesa.work_flow()
    GameSession.mesa.work_flow()
    if not str(room.call("get_interaction_hint")).contains("valves"):
        _fail("Real scene missing discoverable irrigation interaction")
        return
    await _tap(KEY_E)
    await _tap(KEY_E)
    if not GameSession.mesa.court_restored():
        _fail("Real mapped E did not restore living court")
        return
    var lamp: PointLight2D = room.get("_court_light") as PointLight2D
    if lamp == null or lamp.energy < 0.5:
        _fail("Court restoration didn't change live light")
        return
    GameSession.advance_time(721.0)
    yuna.position = room.GROWING_BED
    GameSession.condition.nourishment = 17.0
    await get_tree().process_frame
    if not str(room.call("get_interaction_hint")).contains("fresh"):
        _fail("Ready physical harvest didn't offer an E prompt")
        return
    await _tap(KEY_E)
    if GameSession.mesa.court_ready or GameSession.condition.nourishment <= 17.0:
        _fail("Real E harvest did not feed Yuna exactly once")
        return
    var after_eat: float = GameSession.condition.nourishment
    await _tap(KEY_E)
    if (GameSession.condition.nourishment > after_eat
            or GameSession.condition.nourishment < after_eat - 1.0
            or GameSession.mesa.court_ready):
        _fail("Repeated E obtained another harvest instead of normal passive hunger")
        return

    # The same placement node powers both homes, with distinct authoritative layouts.
    if not decor.call("place_at", "rug", Vector2(544, 580)):
        _fail("Could not put an owned rug in the mesa living nook")
        return
    if not decor.call("place_at", "lantern", Vector2(640, 600)):
        _fail("Could not put a real lantern in the mesa living nook")
        return
    if GameSession.bag.total_units() != 0 or GameSession.decor.count_kind("rug") != 1:
        _fail("Mesa furnishing altered original home or failed inventory transfer")
        return
    var lamp_count: int = 0
    var body_count: int = 0
    for child: Node in decor.get_children():
        if child is PointLight2D:
            lamp_count += 1
        if child is StaticBody2D:
            body_count += 1
    if lamp_count != 1 or body_count != 1:
        _fail("Mesa lantern must create real light and solid collision")
        return

    await _tap(KEY_G)
    if not decor.edit_mode or not str(room.call("get_interaction_hint")).contains("Click place"):
        _fail("G arrangement mode not available in actual Mesa scene")
        return
    await _tap(KEY_G)
    if decor.edit_mode:
        _fail("G cannot exit decoration mode")
        return
    if not GameSession.save_to_disk(TEST_SAVE):
        _fail("v14 two-home disk save failed")
        return
    var saved_pos: Vector2 = GameSession.mesa_position
    room.queue_free()
    await get_tree().process_frame
    GameSession.mesa = MesaState.new()
    GameSession.decor = ShelterDecorState.new()
    GameSession.mesa_decor = ShelterDecorState.new(true)
    if not GameSession.load_from_disk(TEST_SAVE):
        _fail("v14 two-home disk load failed")
        return
    if (not GameSession.mesa.court_restored() or GameSession.mesa.court_ready
            or GameSession.decor.count_kind("rug") != 1
            or GameSession.mesa_decor.count_kind("rug") != 1
            or GameSession.mesa_decor.count_kind("lantern") != 1
            or GameSession.mesa_position != saved_pos):
        _fail("Saved growth, position or two different furnished homes lost")
        return
    room = scene.instantiate() as Node2D
    add_child(room)
    decor = room.get_node("ShelterDecorator") as Node2D
    if decor.get_child_count() != 2:
        _fail("Decor did not reappear as lit/solid furniture on re-entry")
        return
    if (room.get("_court_light") as PointLight2D).energy < 0.5:
        _fail("Court light lost after actual room re-entry")
        return
    room.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
    _restore_save()
    print("PASS: real E/G sun court repairs, single harvest, physical decor, separate homes and v14 disk re-entry")
    get_tree().quit(0)


func _tap(key: Key) -> void:
    var down := InputEventKey.new()
    down.physical_keycode = key
    down.pressed = true
    Input.parse_input_event(down)
    await get_tree().process_frame
    await get_tree().process_frame
    var up := InputEventKey.new()
    up.physical_keycode = key
    up.pressed = false
    Input.parse_input_event(up)
    await get_tree().process_frame
    await get_tree().process_frame


func _restore_save() -> void:
    Input.action_release("interact")
    if _had_save:
        var file: FileAccess = FileAccess.open(GameSession.SAVE_PATH, FileAccess.WRITE)
        if file != null:
            file.store_buffer(_player_bytes)
            file.close()
    elif FileAccess.file_exists(GameSession.SAVE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSession.SAVE_PATH))


func _fail(reason: String) -> void:
    _restore_save()
    push_error("P4c court scene: " + reason)
    get_tree().quit(1)
