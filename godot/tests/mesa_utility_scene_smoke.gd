extends Node
## Actual E/Q actions in the sun court: power, warm rest, circulation,
## drinkable water and removal of the solid back-gallery barrier.

const TEST_SAVE: String = "user://nah_p4b_mesa_utilities.json"
var _had_player_save: bool = false
var _original_bytes: PackedByteArray


func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    _had_player_save = FileAccess.file_exists(GameSession.SAVE_PATH)
    if _had_player_save:
        _original_bytes = FileAccess.get_file_as_bytes(GameSession.SAVE_PATH)
    GameSession.mesa = MesaState.new()
    GameSession.mesa.examine()
    for stage: int in range(3):
        GameSession.mesa.turn_handwheel()
    GameSession.mesa.make_first_sector_safe()
    GameSession.current_level = "mesa"
    GameSession.mesa_position = Vector2(217, 552)
    GameSession.shelter_position = Vector2(340, 365)
    GameSession.condition = YunaCondition.new()
    GameSession.bag = InventoryState.new()
    GameSession.decor = ShelterDecorState.new()
    if not GameSession.decor.place("rug", Vector2(448, 384)):
        _fail("Couldn't establish original home's furnishings")
        return
    if not GameSession.bag.try_receive({"coolant_filter": 1}):
        _fail("Could not add optional filter")
        return

    var level: Node2D = (load("res://scenes/interiors/mesa_refuge.tscn") as PackedScene).instantiate() as Node2D
    add_child(level)
    var yuna: CharacterBody2D = level.get_node("Yuna") as CharacterBody2D
    var closed_gate: StaticBody2D = level.get("_rear_barrier") as StaticBody2D
    if closed_gate == null or not is_instance_valid(closed_gate) or not closed_gate.is_inside_tree():
        _fail("Rear machine gallery must begin physically blocked")
        return
    yuna.position = level.POWER_PANEL
    await get_tree().process_frame
    if not str(level.call("get_interaction_hint")).contains("Hand-start power"):
        _fail("Power repair not discoverable in the real room")
        return
    var start_clock: float = GameSession.ecology.elapsed_minutes
    await _tap(KEY_E)
    if GameSession.mesa.power_progress != 1 or GameSession.mesa.power_online():
        _fail("First E did not perform exactly one power work stage")
        return
    await _tap(KEY_E)
    if not GameSession.mesa.power_online() or GameSession.mesa.power_method != "manual":
        _fail("Second E did not energize the room")
        return
    if GameSession.ecology.elapsed_minutes < start_clock + 60.0:
        _fail("Manual electrical repair should advance actual world time")
        return
    var lamp: PointLight2D = level.get("_utility_light") as PointLight2D
    if lamp == null or lamp.energy < 0.5:
        _fail("Restoring the main bus didn't restore physical lighting")
        return

    GameSession.condition.fatigue = 72.0
    yuna.position = level.REST_BENCH
    await get_tree().process_frame
    await _tap(KEY_E)
    if GameSession.condition.fatigue >= 72.0:
        _fail("Powered refuge didn't provide restorative sleep")
        return
    if GameSession.ecology.elapsed_minutes < start_clock + 420.0:
        _fail("Mesa sleep didn't advance offscreen machine ecology")
        return

    yuna.position = level.FLOW_PANEL
    await get_tree().process_frame
    if not str(level.call("get_interaction_hint")).contains("Use filter"):
        _fail("Water-loop repair shortcut not discoverable")
        return
    await _tap(KEY_Q)
    if not GameSession.mesa.flow_online() or GameSession.mesa.flow_method != "filter":
        _fail("Q didn't install optional coolant filter through actual room input")
        return
    if GameSession.bag.quantity(&"coolant_filter") != 0:
        _fail("Actual coolant repair didn't consume exactly one filter")
        return
    if is_instance_valid(closed_gate) and closed_gate.is_inside_tree():
        _fail("Power/water restoration didn't remove solid rear barrier")
        return
    await _tap(KEY_Q)
    if GameSession.bag.quantity(&"coolant_filter") != 0:
        _fail("Repeated Q deducted additional repair material")
        return

    yuna.position = Vector2(930, 340)
    await get_tree().physics_frame
    Input.action_press("move_right")
    for frame: int in range(58):
        await get_tree().physics_frame
    Input.action_release("move_right")
    if yuna.position.x < 1000.0:
        _fail("Player still cannot walk into physically restored rear sector")
        return

    GameSession.condition.hydration = 18.0
    yuna.position = level.WATER_FAUCET
    await get_tree().process_frame
    await _tap(KEY_E)
    if GameSession.condition.hydration <= 18.0:
        _fail("Restored coolant loop didn't provide clean drinking water")
        return

    if not GameSession.save_to_disk(TEST_SAVE):
        _fail("Couldn't save two-home utility state")
        return
    var saved_mesa_position: Vector2 = GameSession.mesa_position
    level.queue_free()
    await get_tree().process_frame
    GameSession.mesa = MesaState.new()
    GameSession.decor = ShelterDecorState.new()
    GameSession.current_level = "outdoors"
    if not GameSession.load_from_disk(TEST_SAVE):
        _fail("Could not load mesa utilities after real FileAccess save")
        return
    if (not GameSession.mesa.power_online() or not GameSession.mesa.flow_online()
            or GameSession.mesa.power_method != "manual" or GameSession.mesa.flow_method != "filter"
            or GameSession.decor.count_kind("rug") != 1 or GameSession.mesa_position != saved_mesa_position):
        _fail("Repaired gallery or original Little Nest lost after reload")
        return
    level = (load("res://scenes/interiors/mesa_refuge.tscn") as PackedScene).instantiate() as Node2D
    add_child(level)
    if is_instance_valid(level.get("_rear_barrier")):
        _fail("Reloaded repaired mesa unexpectedly resealed the gallery")
        return
    level.queue_free()
    await get_tree().process_frame

    DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
    _restore_player_save()
    print("PASS: physical E/Q mesa repairs, room light, rest, rear traversal, clean water and two-home disk persistence")
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
    if _had_player_save:
        var file: FileAccess = FileAccess.open(GameSession.SAVE_PATH, FileAccess.WRITE)
        if file != null:
            file.store_buffer(_original_bytes)
            file.close()
    elif FileAccess.file_exists(GameSession.SAVE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSession.SAVE_PATH))


func _fail(message: String) -> void:
    _restore_player_save()
    push_error("P4b utility room failure: " + message)
    get_tree().quit(1)
