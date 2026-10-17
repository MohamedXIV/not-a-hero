extends Node
## A game-first regression: standing between two interactables must operate
## the prop whose prompt is actually shown, not arbitrary streamed node order.
## Also exercises Yuna's recuperation at the inhabited lower thermal gallery.

var _had_save: bool = false
var _save_bytes: PackedByteArray


func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    _had_save = FileAccess.file_exists(GameSession.SAVE_PATH)
    if _had_save:
        _save_bytes = FileAccess.get_file_as_bytes(GameSession.SAVE_PATH)

    GameSession.mesa = MesaState.new()
    GameSession.notebook = NotebookState.new()
    GameSession.current_level = "outdoors"
    GameSession.outdoor_position = Vector2(2444, 233)
    GameSession.bag = InventoryState.new()
    GameSession.bag.try_receive({"relay_fuse": 1})
    GameSession.voice = YunaVoice.new()
    var world: Node2D = (load("res://scenes/world/outdoors.tscn") as PackedScene).instantiate() as Node2D
    add_child(world)
    var yuna: CharacterBody2D = world.get_node("Yuna") as CharacterBody2D
    await get_tree().process_frame

    # The Basin manifold is inserted BEFORE the Mesa hatch in the chunk.
    # At this overlapping point the manifold really is closer; no invisible
    # Q action should silently open the slightly farther hatch.
    yuna.position = Vector2(2444, 233)
    await get_tree().process_frame
    var focused: Node2D = world.call("_nearest_interactable") as Node2D
    if focused == null or focused.name != "BuriedReturnManifold" or not str(world.call("get_interaction_hint")).contains("service return"):
        _fail("Outdoor prompt ignored nearer manuscript/manifold in overlapping range")
        return
    await _tap(KEY_Q)
    if GameSession.mesa.is_open() or GameSession.bag.quantity(&"relay_fuse") != 1:
        _fail("Invisible Q activated a nonfocused Mesa door")
        return
    await _tap(KEY_E)
    if not GameSession.notebook.knows("basin_return_manifold") or GameSession.mesa.inspected:
        _fail("Outdoor E didn't inspect the nearest clue")
        return
    # Stand on the hatch side of the same interaction overlap.
    yuna.position = Vector2(2443, 210)
    await get_tree().process_frame
    focused = world.call("_nearest_interactable") as Node2D
    if focused == null or focused.name != "MesaEntrance" or not str(world.call("get_interaction_hint")).contains("hatch"):
        _fail("Outdoor closest hatch did not own the visible prompt")
        return
    await _tap(KEY_E)
    if not GameSession.mesa.inspected:
        _fail("Outdoor E didn't inspect nearer hatch")
        return
    await _tap(KEY_Q)
    if GameSession.mesa.access_method != "fuse" or GameSession.bag.quantity(&"relay_fuse") != 0:
        _fail("Outdoor Q didn't apply to the focused fuse-ready hatch")
        return
    yuna.position = Vector2(2444, 233)
    await get_tree().process_frame
    var signal_count: Array[String] = []
    world.transition_requested.connect(func(dest: String) -> void: signal_count.append(dest))
    await _tap(KEY_E)
    if not signal_count.is_empty():
        _fail("Opened Mesa wrongly kidnapped E input from nearer basin observation")
        return

    world.queue_free()
    await get_tree().process_frame

    # Prepare a genuinely workable but still unfurnished rear gallery for
    # in-world nearest-choice proof at THREE overlapping interactable pairs.
    GameSession.mesa.make_first_sector_safe()
    GameSession.mesa.work_power()
    GameSession.mesa.work_power()
    GameSession.mesa.work_flow()
    GameSession.mesa.work_flow()
    GameSession.current_level = "mesa"
    GameSession.mesa_position = Vector2(1094, 213)
    var refuge: Node2D = (load("res://scenes/interiors/mesa_refuge.tscn") as PackedScene).instantiate() as Node2D
    add_child(refuge)
    yuna = refuge.get_node("Yuna") as CharacterBody2D
    await get_tree().process_frame
    yuna.position = Vector2(1094, 213)  # 32 px to screen, 33 px to lift
    await get_tree().process_frame
    if str(refuge.call("_interaction_target")) != "nook" or not str(refuge.call("get_interaction_hint")).contains("acoustic screen"):
        _fail("Closer acoustic screen was hidden by upper lift prompt")
        return
    await _tap(KEY_E)
    if not GameSession.mesa.rear_nook_prepared or GameSession.mesa.depth_open:
        _fail("Real E repaired lift instead of physically nearer nook")
        return
    yuna.position = Vector2(1105, 226) # 17 px to lift, 48 px to screen
    await get_tree().process_frame
    if str(refuge.call("_interaction_target")) != "lift" or not str(refuge.call("get_interaction_hint")).contains("40 minutes"):
        _fail("Closer lift should win when standing by its own door")
        return
    await _tap(KEY_E)
    if not GameSession.mesa.depth_open:
        _fail("Closer lift didn't release with real E")
        return

    # Near the cot and return carrier: the cot is closer at the midpoint.
    yuna.position = Vector2(1068, 473)
    await get_tree().process_frame
    if str(refuge.call("_interaction_target")) != "nook" or not str(refuge.call("get_interaction_hint")).contains("Rest"):
        _fail("Closest cot prompt lost to service carrier")
        return
    GameSession.condition = YunaCondition.new()
    GameSession.condition.fatigue = 75.0
    await _tap(KEY_E)
    if GameSession.condition.fatigue >= 75.0 or GameSession.mesa.service_signal_inspected:
        _fail("Real E inspected carrier rather than using the nearby cot")
        return

    yuna.position = Vector2(1060, 522)
    await get_tree().process_frame
    if str(refuge.call("_interaction_target")) != "carrier" or not str(refuge.call("get_interaction_hint")).contains("Read the repeating"):
        _fail("Carrier at the directly approached terminal is not focused")
        return
    await _tap(KEY_E)
    if not GameSession.mesa.service_signal_inspected or not GameSession.notebook.knows("mesa_return_carrier"):
        _fail("Focused carrier E failed to observe the actual signal")
        return

    refuge.queue_free()
    await get_tree().process_frame

    # Lower gallery must become genuinely safer when Yuna restores warmth;
    # checking the controller itself catches an environment-tag wiring bug.
    GameSession.current_level = "mesa_depth"
    GameSession.mesa_depth_position = Vector2(211, 493)
    var lower: Node2D = (load("res://scenes/interiors/mesa_depth_chamber.tscn") as PackedScene).instantiate() as Node2D
    add_child(lower)
    yuna = lower.get_node("Yuna") as CharacterBody2D
    GameSession.condition = YunaCondition.new()
    GameSession.condition.fatigue = 20.0
    yuna.call("_physics_process", 10.0)
    var cold_fatigue: float = GameSession.condition.fatigue - 20.0
    var cold_composure: float = GameSession.condition.composure
    GameSession.mesa.depth_archive_read = true
    GameSession.mesa.depth_warm = true
    lower.call("_refresh")
    GameSession.condition = YunaCondition.new()
    GameSession.condition.fatigue = 20.0
    yuna.call("_physics_process", 10.0)
    var warm_fatigue: float = GameSession.condition.fatigue - 20.0
    if (cold_fatigue < warm_fatigue + 0.10
            or GameSession.condition.composure < cold_composure + 2.0):
        _fail("Yuna controller ignores a warmed lower home for normal recovery rates")
        return

    lower.queue_free()
    await get_tree().process_frame
    _restore_save()
    print("PASS: prompts and E/Q choose nearest streamed prop and Mesa console; warm lower home really improves Yuna recovery")
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
    Input.action_release("mesa_repair")
    if _had_save:
        var file: FileAccess = FileAccess.open(GameSession.SAVE_PATH, FileAccess.WRITE)
        if file != null:
            file.store_buffer(_save_bytes)
            file.close()
    elif FileAccess.file_exists(GameSession.SAVE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSession.SAVE_PATH))


func _fail(message: String) -> void:
    _restore_save()
    push_error("P4g interaction focus: " + message)
    get_tree().quit(1)
