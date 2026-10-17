extends Node
## The real Main scene, input E, both distinct floors, no compulsory clue,
## a genuine warm seat, saving from below and returning to an intact refuge.

const TEST_SAVE: String = "user://nah_p4f_depth_test.json"
var _had_save: bool = false
var _player_bytes: PackedByteArray


func _ready() -> void:
    call_deferred("_check")


func _prepare() -> void:
    GameSession.mesa = MesaState.new()
    GameSession.mesa.examine()
    for i: int in range(3):
        GameSession.mesa.turn_handwheel()
    GameSession.mesa.make_first_sector_safe()
    GameSession.mesa.work_power()
    GameSession.mesa.work_power()
    GameSession.current_level = "mesa"
    GameSession.mesa_position = Vector2(1110, 242)
    GameSession.mesa_depth_position = Vector2(211, 493)
    GameSession.notebook = NotebookState.new()
    GameSession.voice = YunaVoice.new()
    GameSession.bag = InventoryState.new()
    GameSession.decor = ShelterDecorState.new()
    GameSession.mesa_decor = ShelterDecorState.new(true)
    GameSession.condition = YunaCondition.new()


func _check() -> void:
    _had_save = FileAccess.file_exists(GameSession.SAVE_PATH)
    if _had_save:
        _player_bytes = FileAccess.get_file_as_bytes(GameSession.SAVE_PATH)
    _prepare()
    if not GameSession.save_to_disk():
        _fail("Unable to write fixture for Main's genuine startup")
        return
    var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node2D
    add_child(main)
    var room: Node2D = main.get("_level") as Node2D
    if GameSession.current_level != "mesa" or room == null:
        _fail("Main didn't load the live Mesa fixture")
        return
    var yuna: CharacterBody2D = room.get_node("Yuna") as CharacterBody2D
    var lift: MesaDepthLift = room.get_node_or_null("DepthLift") as MesaDepthLift
    if lift == null:
        _fail("No physical service lift near the back gallery")
        return
    yuna.position = lift.position
    await get_tree().process_frame
    if not str(room.call("get_interaction_hint")).contains("pressure isolation"):
        _fail("The sealed lift didn't explain its causal lock")
        return
    await _tap(KEY_E)
    if GameSession.mesa.depth_open or GameSession.current_level != "mesa":
        _fail("E opened the lower gallery before circulation")
        return
    yuna.position = room.FLOW_PANEL
    await get_tree().process_frame
    await _tap(KEY_E)
    await _tap(KEY_E)
    if not GameSession.mesa.flow_online():
        _fail("Real E didn't repair the coolant line")
        return
    yuna.position = lift.position
    await get_tree().process_frame
    if not str(room.call("get_interaction_hint")).contains("40 minutes"):
        _fail("Material-free hand release is undiscoverable")
        return
    var before: float = GameSession.ecology.elapsed_minutes
    await _tap(KEY_E)
    if (not GameSession.mesa.depth_open or GameSession.current_level != "mesa"
            or GameSession.ecology.elapsed_minutes < before + 40.0):
        _fail("First E didn't release actual lift with deterministic world cost")
        return
    await _tap(KEY_E)
    if GameSession.current_level != "mesa_depth":
        _fail("Second E didn't pass through Main into a separate lower level")
        return
    room = main.get("_level") as Node2D
    if room == null or not room.has_method("get_interaction_hint"):
        _fail("Main did not instantiate the new lower gallery")
        return
    yuna = room.get_node("Yuna") as CharacterBody2D
    if GameSession.notebook.knows("mesa_thermal_archive"):
        _fail("Entering the room wrongly gave away an unobserved secret")
        return

    yuna.position = room.REGULATOR_POINT
    await get_tree().process_frame
    if not str(room.call("get_interaction_hint")).contains("read the preserved log"):
        _fail("Regulator did not protect against uninformed switching")
        return
    await _tap(KEY_E)
    if GameSession.mesa.depth_warm:
        _fail("Temperature changed without observed working range")
        return

    yuna.position = room.ARCHIVE_POINT
    await get_tree().process_frame
    if not str(room.call("get_interaction_hint")).contains("preserved temperature log"):
        _fail("Archive isn't physically discoverable")
        return
    await _tap(KEY_E)
    if (not GameSession.mesa.depth_archive_read
            or not GameSession.notebook.knows("mesa_thermal_archive")
            or not GameSession.notebook.related_inferences("mesa_thermal_archive").is_empty()):
        _fail("Archive E did not record only personally witnessed evidence")
        return

    yuna.position = room.REST_POINT
    GameSession.condition.fatigue = 65.0
    await get_tree().process_frame
    await _tap(KEY_E)
    if GameSession.condition.fatigue < 64.0:
        _fail("Cold service area was an unexplained free resting station")
        return

    yuna.position = room.REGULATOR_POINT
    await get_tree().process_frame
    before = GameSession.ecology.elapsed_minutes
    await _tap(KEY_E)
    var cradle_light: PointLight2D = room.get("_cradle_light") as PointLight2D
    if (not GameSession.mesa.depth_warm or cradle_light == null
            or cradle_light.energy < 1.0
            or GameSession.ecology.elapsed_minutes < before + 20.0):
        _fail("Real E didn't warm and light the empty archive through actual world time")
        return
    yuna.position = room.REST_POINT
    await get_tree().process_frame
    await _tap(KEY_E)
    if GameSession.condition.fatigue >= 65.0:
        _fail("Resting in the actually warm lower area failed")
        return
    if GameSession.mesa.first_night_spent or GameSession.mesa.court_restored():
        _fail("Thermal gallery forged the separate first-night/court progression")
        return

    if not GameSession.save_to_disk(TEST_SAVE):
        _fail("v17 lower level snapshot not written")
        return
    var position: Vector2 = GameSession.mesa_depth_position
    GameSession.mesa = MesaState.new()
    GameSession.notebook = NotebookState.new()
    GameSession.current_level = "outdoors"
    if not GameSession.load_from_disk(TEST_SAVE):
        _fail("v17 lower floor Save + Load invalid")
        return
    if (not GameSession.mesa.depth_warm or not GameSession.mesa.depth_archive_read
            or not GameSession.notebook.knows("mesa_thermal_archive")
            or GameSession.current_level != "mesa_depth"
            or GameSession.mesa_depth_position != position):
        _fail("Lower level, thermal state, journal or position lost after disk reload")
        return

    main.call("_open_level", GameSession.current_level)
    room = main.get("_level") as Node2D
    cradle_light = room.get("_cradle_light") as PointLight2D
    if cradle_light == null or cradle_light.energy < 1.0:
        _fail("Reopened scene lost physical warmth")
        return
    # Confirm reversible lower-level access, even after Save + Load, with Main.
    yuna = room.get_node("Yuna") as CharacterBody2D
    yuna.position = room.EXIT_POINT
    for i: int in range(45):
        await get_tree().process_frame
    # Hold E beyond the Main transition cooldown and echo a browser-like
    # key repeat. It must not immediately descend back into the lower lift.
    await _hold_exit_with_repeat()
    if GameSession.current_level != "mesa":
        _fail("Held/repeating E bounced right back from the upper Mesa lift")
        return
    room = main.get("_level") as Node2D
    if room.get_node_or_null("RearNook") == null or room.get_node_or_null("ShelterDecorator") == null:
        _fail("The original home rooms were replaced or destroyed by lower chamber")
        return
    if GameSession.mesa.depth_warm != true:
        _fail("Leaving the lower room unexpectedly disabled warmth")
        return

    # A rerouted carrier creates an alternative free lift opening, without
    # being a prerequisite for normal/manual access.
    var second := MesaState.new()
    second.examine()
    for i: int in range(3):
        second.turn_handwheel()
    second.make_first_sector_safe()
    second.work_power()
    second.work_power()
    second.work_flow()
    second.work_flow()
    assert(second.inspect_service_signal() and second.toggle_service_signal())
    var fast_lift := MesaDepthLift.new()
    add_child(fast_lift)
    GameSession.mesa = second
    GameSession.current_level = "mesa"
    before = GameSession.ecology.elapsed_minutes
    assert(fast_lift.interact_at(fast_lift.global_position))
    if not GameSession.mesa.depth_open or GameSession.ecology.elapsed_minutes > before + 1.0:
        _fail("Optional earlier carrier reroute didn't avoid the 40-minute hand-release")
        return
    fast_lift.queue_free()
    await get_tree().process_frame
    main.queue_free()
    await get_tree().process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
    _restore_save()
    print("PASS: real Main E lift, new playable level, unobserved archival secret, warm/cold rest, optional shortcut and v17 disk return")
    get_tree().quit(0)


func _hold_exit_with_repeat() -> void:
    var down := InputEventKey.new()
    down.physical_keycode = KEY_E
    down.pressed = true
    Input.parse_input_event(down)
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().create_timer(0.65).timeout
    var repeated := InputEventKey.new()
    repeated.physical_keycode = KEY_E
    repeated.pressed = true
    repeated.echo = true
    Input.parse_input_event(repeated)
    await get_tree().process_frame
    await get_tree().process_frame
    var up := InputEventKey.new()
    up.physical_keycode = KEY_E
    up.pressed = false
    Input.parse_input_event(up)
    await get_tree().process_frame
    await get_tree().process_frame


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


func _fail(message: String) -> void:
    _restore_save()
    push_error("P4f depth scene: " + message)
    get_tree().quit(1)
