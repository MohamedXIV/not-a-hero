extends Node
## Real E presses into a traversable new rear alcove and first optional night.
## Tests lighting/collision, chronology, ecology, two-home JSON disk persistence,
## and rebuilt scene state. Preserves an existing local player's save.

const TEST_SAVE: String = "user://nah_p4d_first_night_test.json"
var _had_player_save: bool = false
var _player_bytes: PackedByteArray


func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    _had_player_save = FileAccess.file_exists(GameSession.SAVE_PATH)
    if _had_player_save:
        _player_bytes = FileAccess.get_file_as_bytes(GameSession.SAVE_PATH)
    GameSession.mesa = MesaState.new()
    GameSession.mesa.examine()
    for i: int in range(3):
        GameSession.mesa.turn_handwheel()
    GameSession.mesa.make_first_sector_safe()
    GameSession.mesa.work_power()
    GameSession.mesa.work_power()
    GameSession.current_level = "mesa"
    GameSession.mesa_position = Vector2(217, 552)
    GameSession.shelter_position = Vector2(340, 365)
    GameSession.bag = InventoryState.new()
    GameSession.decor = ShelterDecorState.new()
    GameSession.mesa_decor = ShelterDecorState.new(true)
    GameSession.condition = YunaCondition.new()
    GameSession.notebook = NotebookState.new()
    if not GameSession.decor.place("rug", Vector2(448, 384)):
        _fail("Original home's favorite rug could not be prepared")
        return
    if not GameSession.mesa_decor.place("lantern", Vector2(640, 600)):
        _fail("Second home's independent furniture could not be prepared")
        return

    var scene: PackedScene = load("res://scenes/interiors/mesa_refuge.tscn") as PackedScene
    var refuge: Node2D = scene.instantiate() as Node2D
    add_child(refuge)
    var yuna: CharacterBody2D = refuge.get_node("Yuna") as CharacterBody2D
    var nook: MesaRearNook = refuge.get_node("RearNook") as MesaRearNook
    if nook == null:
        _fail("Physical scene has no independent rear nook")
        return
    if nook.get("_warm_light") == null or (nook.get("_warm_light") as PointLight2D).energy > 0.0:
        _fail("Unprepared nook unexpectedly has a warm practical lamp")
        return

    yuna.position = nook.PANEL_POINT
    await get_tree().process_frame
    if not str(refuge.call("get_interaction_hint")).contains("sealed"):
        _fail("Sealed gallery interaction is not explained in the real scene")
        return
    await _tap(KEY_E)
    if GameSession.mesa.rear_nook_prepared:
        _fail("E bypassed unrepaired coolant lock")
        return

    # Restore coolant through the existing REAL E panel, not a model shortcut.
    yuna.position = refuge.FLOW_PANEL
    await get_tree().process_frame
    await _tap(KEY_E)
    await _tap(KEY_E)
    if not GameSession.mesa.flow_online() or is_instance_valid(refuge.get("_rear_barrier")):
        _fail("Existing E circulation did not physically open the rear gallery")
        return

    yuna.position = Vector2(929, 340)
    await get_tree().physics_frame
    Input.action_press("move_right")
    for i: int in range(60):
        await get_tree().physics_frame
    Input.action_release("move_right")
    if yuna.position.x < 1000.0:
        _fail("Yuna cannot actually walk into the newly usable room")
        return

    yuna.position = nook.PANEL_POINT
    await get_tree().process_frame
    if not str(refuge.call("get_interaction_hint")).contains("acoustic screen"):
        _fail("Real rear-gallery screen interaction is not discoverable")
        return
    var before: float = GameSession.ecology.elapsed_minutes
    await _tap(KEY_E)
    var cot: StaticBody2D = nook.get("_cot_body") as StaticBody2D
    var warm_lamp: PointLight2D = nook.get("_warm_light") as PointLight2D
    if (not GameSession.mesa.rear_nook_prepared or cot == null
            or not is_instance_valid(cot) or not cot.is_inside_tree()
            or warm_lamp.energy < 0.45):
        _fail("E didn't make a physically solid, lamp-lit sheltered corner")
        return
    if GameSession.ecology.elapsed_minutes < before + nook.NOOK_WORK_MINUTES:
        _fail("Physical rebuilding didn't advance world/ecology time")
        return
    await _tap(KEY_E)
    if GameSession.mesa.first_night_spent or GameSession.mesa.court_progress != 0:
        _fail("Repeated panel E manufactured a milestone or bypassed the garden")
        return

    # Prepared cot works immediately, even when there are no garden rewards.
    GameSession.condition.fatigue = 68.0
    yuna.position = nook.REST_POINT
    await get_tree().process_frame
    if not str(refuge.call("get_interaction_hint")).contains("Rest"):
        _fail("Prepared real cot doesn't offer a usable rest prompt")
        return
    before = GameSession.ecology.elapsed_minutes
    await _tap(KEY_E)
    if (GameSession.condition.fatigue >= 68.0
            or GameSession.ecology.elapsed_minutes < before + 360.0
            or GameSession.mesa.first_night_spent):
        _fail("Normal pre-court sleep failed or triggered story milestone too early")
        return

    # Repair the living court in-world, then CHOOSE to sleep here again.
    yuna.position = refuge.COURT_CONTROL
    await get_tree().process_frame
    await _tap(KEY_E)
    await _tap(KEY_E)
    if not GameSession.mesa.court_restored():
        _fail("Mapped E didn't activate court before first-night opportunity")
        return
    yuna.position = nook.REST_POINT
    await get_tree().process_frame
    if not str(refuge.call("get_interaction_hint")).contains("first night"):
        _fail("Milestone invitation is absent after actually restoring both spaces")
        return
    GameSession.condition.fatigue = 60.0
    await _tap(KEY_E)
    if (not GameSession.mesa.first_night_spent
            or warm_lamp.energy < 0.8
            or GameSession.condition.fatigue >= 60.0):
        _fail("First chosen night didn't persist or feel visibly different")
        return
    if GameSession.voice.current_event() != &"mesa_first_night":
        _fail("No contextual, second-person first-night emotional line")
        return
    await _tap(KEY_E)
    if not GameSession.mesa.first_night_spent or GameSession.bag.total_units() != 0:
        _fail("Rest repeated the one-time milestone or manufactured inventory")
        return

    if not GameSession.save_to_disk(TEST_SAVE):
        _fail("v15 saved evening didn't reach actual FileAccess disk")
        return
    var saved_position: Vector2 = GameSession.mesa_position
    refuge.queue_free()
    await get_tree().process_frame
    GameSession.mesa = MesaState.new()
    GameSession.decor = ShelterDecorState.new()
    GameSession.mesa_decor = ShelterDecorState.new(true)
    GameSession.current_level = "outdoors"
    if not GameSession.load_from_disk(TEST_SAVE):
        _fail("v15 disk snapshot could not restore")
        return
    if (not GameSession.mesa.rear_nook_prepared or not GameSession.mesa.first_night_spent
            or not GameSession.mesa.court_restored()
            or GameSession.decor.count_kind("rug") != 1
            or GameSession.mesa_decor.count_kind("lantern") != 1
            or GameSession.mesa_position != saved_position
            or GameSession.current_level != "mesa"):
        _fail("Reload lost first-night milestone or either independent home's furnishings")
        return

    refuge = scene.instantiate() as Node2D
    add_child(refuge)
    nook = refuge.get_node("RearNook") as MesaRearNook
    warm_lamp = nook.get("_warm_light") as PointLight2D
    if (warm_lamp.energy < 0.8
            or not is_instance_valid(nook.get("_cot_body"))):
        _fail("Re-entered Mesa didn't reconstruct the warm physical sleeping corner")
        return
    refuge.queue_free()
    await get_tree().process_frame
    GameSession.current_level = "shelter"
    var nest: Node2D = (load("res://scenes/interiors/starter_shelter.tscn") as PackedScene).instantiate() as Node2D
    add_child(nest)
    if (nest.get_node_or_null("ShelterDecorator") == null
            or GameSession.decor.count_kind("rug") != 1):
        _fail("Original Little Nest was replaced or lost its furnishings")
        return
    nest.queue_free()
    await get_tree().process_frame

    DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
    _restore_player_save()
    print("PASS: traversable rear gallery, E-built cot, garden-optional sleep, first night, real light/collision and v15 two-home disk re-entry")
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


func _restore_player_save() -> void:
    Input.action_release("move_right")
    Input.action_release("interact")
    if _had_player_save:
        var file: FileAccess = FileAccess.open(GameSession.SAVE_PATH, FileAccess.WRITE)
        if file != null:
            file.store_buffer(_player_bytes)
            file.close()
    elif FileAccess.file_exists(GameSession.SAVE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSession.SAVE_PATH))


func _fail(reason: String) -> void:
    _restore_player_save()
    push_error("P4d first night: " + reason)
    get_tree().quit(1)
