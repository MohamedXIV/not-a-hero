extends Node
## P4a true gameplay integration: press actual E/Q actions through Main's
## connected outdoors/interior/shelter scenes. Never calls hatch methods directly.
## Preserve an existing default user save when this scene test runs locally.

const MAIN: PackedScene = preload("res://scenes/main.tscn")
const SAVE_PATH: String = "user://not_a_hero_save.json"

var _had_player_save: bool = false
var _player_bytes: PackedByteArray


func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    _had_player_save = FileAccess.file_exists(SAVE_PATH)
    if _had_player_save:
        _player_bytes = FileAccess.get_file_as_bytes(SAVE_PATH)
    _clear_test_save()

    for method: String in ["manual", "fuse"]:
        if not await _exercise_route(method):
            return
        _clear_test_save()

    _restore_player_save()
    print("PASS: real E/Q mesa access, Main level transitions, safe room, Little Nest return and disk revisit")
    get_tree().quit(0)


func _exercise_route(method: String) -> bool:
    GameSession.current_level = "shelter"
    GameSession.shelter_position = Vector2(340, 365)
    GameSession.outdoor_position = Vector2(2420, 172)
    GameSession.mesa_position = Vector2(217, 552)
    GameSession.mesa = MesaState.new()
    GameSession.notebook = NotebookState.new()
    GameSession.decor = ShelterDecorState.new()
    GameSession.bag = InventoryState.new()
    if not GameSession.bag.try_receive({"rug": 1, "relay_fuse": 1}):
        _fail("Could not prepare a clean player bag")
        return false

    var main: Node2D = MAIN.instantiate() as Node2D
    add_child(main)
    main.call("_open_level", "outdoors")
    var outside: Node2D = main.get("_level") as Node2D
    var yuna: CharacterBody2D = outside.get_node("Yuna") as CharacterBody2D
    yuna.position = Vector2(2420, 172)
    await get_tree().process_frame
    var marker: Node2D = outside.get_node_or_null(
        "WorldStreamer/CoolantBasinChunk/MesaEntrance"
    ) as Node2D
    if marker == null or not str(outside.call("get_interaction_hint")).contains("Examine"):
        _fail("Can't find an interactive physical mesa entrance from normal exterior")
        return false

    # E: inspect in the actual exterior scene, without any notebook clues.
    await _tap("interact")
    if not GameSession.mesa.inspected:
        _fail("Exterior E failed to inspect the real door")
        return false

    if method == "manual":
        for stage: int in range(MesaState.MANUAL_STAGES):
            await _tap("interact")
            if GameSession.mesa.manual_progress != stage + 1:
                _fail("Exterior E missed manual cam stage %d" % (stage + 1))
                return false
        if GameSession.mesa.access_method != "manual":
            _fail("Exterior E never completed handwheel route")
            return false
        if GameSession.bag.quantity(&"relay_fuse") != 1:
            _fail("Manual entry incorrectly spent a fuse")
            return false
    else:
        await _tap("mesa_repair")
        if GameSession.mesa.access_method != "fuse":
            _fail("Exterior Q action didn't couple the relay fuse")
            return false
        if GameSession.bag.quantity(&"relay_fuse") != 0:
            _fail("Fused entry didn't spend precisely one relay fuse")
            return false

    if GameSession.current_level != "outdoors":
        _fail("Opening the door should not automatically teleport the player")
        return false
    await _tap("interact")
    var refuge: Node2D = main.get("_level") as Node2D
    if GameSession.current_level != "mesa" or refuge == outside:
        _fail("E at opened physical hatch did not switch Main into mesa")
        return false
    if refuge.get_node_or_null("Yuna") == null or GameSession.notebook.observed_ids().size() != 0:
        _fail("Mesa entry requires absent journal clues or failed to spawn Yuna")
        return false

    # Use E at the actual interior safety panel.
    var mesa_yuna: CharacterBody2D = refuge.get_node("Yuna") as CharacterBody2D
    mesa_yuna.position = refuge.SAFETY_PANEL
    await get_tree().process_frame
    await _tap("interact")
    if not GameSession.mesa.first_sector_safe:
        _fail("Interior E didn't make the first sector safe")
        return false

    # Exit with E through Main, not by calling the signal directly.
    mesa_yuna.position = refuge.EXIT_POINT
    await get_tree().process_frame
    var exit_signals: Array[String] = []
    refuge.transition_requested.connect(func(dest: String) -> void: exit_signals.append(dest))
    await get_tree().create_timer(0.5).timeout
    await _tap("interact")
    outside = main.get("_level") as Node2D
    if GameSession.current_level != "outdoors" or outside == refuge:
        print("DIAGNOSTIC: mesa exit method=%s level=%s hint=%s player=%s delta_ms=%d layer=%s" % [
            method, GameSession.current_level, str(refuge.call("get_interaction_hint")),
            str(mesa_yuna.position), Time.get_ticks_msec() - int(main.get("_last_transition_msec")),
            str(outside.name),
        ])
        print("DIAGNOSTIC: exit_signals=%s input_pressed=%s" % [str(exit_signals), str(Input.is_action_pressed("interact"))])
        _fail("Interior exit E failed to bring Yuna outdoors")
        return false
    if GameSession.outdoor_position.distance_to(Vector2(2420, 172)) > 1.0:
        _fail("Returning from mesa misplaced Yuna")
        return false

    # The original Little Nest remains accessible on the same world.
    yuna = outside.get_node("Yuna") as CharacterBody2D
    yuna.position = outside.HATCH_POSITION
    await get_tree().process_frame
    await get_tree().create_timer(0.5).timeout
    await _tap("interact")
    var nest: Node2D = main.get("_level") as Node2D
    if GameSession.current_level != "shelter":
        _fail("Could not return to original Little Nest after opening mesa")
        return false
    var decorator: Node2D = nest.get_node("ShelterDecorator") as Node2D
    if not bool(decorator.call("place_at", "rug", Vector2(448, 384))):
        _fail("Original home can't be furnished after the mesa trip")
        return false
    if not GameSession.save_to_disk():
        _fail("Failed saving two-home state to disk")
        return false

    main.queue_free()
    await get_tree().process_frame

    # Start a FRESH Main, which reads the actual persisted file.
    var reloaded: Node2D = MAIN.instantiate() as Node2D
    add_child(reloaded)
    if (GameSession.current_level != "shelter"
            or GameSession.mesa.access_method != method
            or not GameSession.mesa.first_sector_safe
            or GameSession.decor.count_kind("rug") != 1):
        _fail("New Main couldn't reload both independent homes")
        return false

    var live_nest: Node2D = reloaded.get("_level") as Node2D
    var nest_yuna: CharacterBody2D = live_nest.get_node("Yuna") as CharacterBody2D
    nest_yuna.position = live_nest.EXIT_POSITION
    await get_tree().process_frame
    await _tap("interact")
    if GameSession.current_level != "outdoors":
        _fail("After reload, Little Nest exit no longer works")
        return false

    # Revisit the physically opened mesa via E without paying materials again.
    var live_outside: Node2D = reloaded.get("_level") as Node2D
    var last_yuna: CharacterBody2D = live_outside.get_node("Yuna") as CharacterBody2D
    last_yuna.position = Vector2(2420, 172)
    await get_tree().process_frame
    await get_tree().create_timer(0.5).timeout
    await _tap("interact")
    if (GameSession.current_level != "mesa"
            or not GameSession.mesa.first_sector_safe
            or GameSession.mesa.access_method != method):
        _fail("Saved opened mesa wasn't accessible via E after full game restart")
        return false
    if GameSession.decor.count_kind("rug") != 1:
        _fail("Revisiting mesa erased Little Nest furniture")
        return false

    reloaded.queue_free()
    await get_tree().process_frame
    return true


func _tap(action_name: String) -> void:
    Input.action_press(action_name)
    await get_tree().process_frame
    Input.action_release(action_name)
    await get_tree().process_frame


func _clear_test_save() -> void:
    if FileAccess.file_exists(SAVE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _restore_player_save() -> void:
    Input.action_release("interact")
    Input.action_release("mesa_repair")
    if _had_player_save:
        var out: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
        if out != null:
            out.store_buffer(_player_bytes)
            out.close()
    else:
        _clear_test_save()


func _fail(message: String) -> void:
    _restore_player_save()
    push_error("Mesa player route: " + message)
    get_tree().quit(1)
