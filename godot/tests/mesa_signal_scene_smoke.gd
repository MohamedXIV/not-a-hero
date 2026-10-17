extends Node
## Full Godot input/world proof for P4e. The curious servitor responds
## physically and deterministically to a switch in a different streamed level.

const TEST_SAVE: String = "user://nah_p4e_signal_test.json"
var _had_save: bool = false
var _save_bytes: PackedByteArray


func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    _had_save = FileAccess.file_exists(GameSession.SAVE_PATH)
    if _had_save:
        _save_bytes = FileAccess.get_file_as_bytes(GameSession.SAVE_PATH)

    GameSession.current_level = "outdoors"
    GameSession.outdoor_position = Vector2(2243, 260)
    GameSession.mesa = MesaState.new()
    GameSession.ecology = MachineEcology.new()
    GameSession.notebook = NotebookState.new()
    GameSession.voice = YunaVoice.new()
    GameSession.bag = InventoryState.new()
    GameSession.decor = ShelterDecorState.new()
    GameSession.mesa_decor = ShelterDecorState.new(true)
    var outdoors_scene := load("res://scenes/world/outdoors.tscn") as PackedScene
    var outdoors: Node2D = outdoors_scene.instantiate() as Node2D
    add_child(outdoors)
    var walker: CharacterBody2D = outdoors.get_node("Yuna") as CharacterBody2D
    walker.position = Vector2(2243, 260)
    outdoors.call("_sync_chunks")
    await get_tree().process_frame
    var marker: Node2D = outdoors.get_node_or_null("WorldStreamer/CoolantBasinChunk/MesaServiceTracks") as Node2D
    var worker: CharacterBody2D = outdoors.get_node_or_null("WorldStreamer/CoolantBasinChunk/MesaPryServitor") as CharacterBody2D
    if marker == null or worker == null:
        _fail("No physical evidence or curious machine outside the Mesa")
        return
    if GameSession.notebook.knows("mesa_return_carrier") or not GameSession.notebook.inference().is_empty():
        _fail("The world prefilled an unwitnessed deep-Mesa explanation")
        return
    if not str(outdoors.call("get_interaction_hint")).contains("Service tracks"):
        _fail("The outside machine clue cannot be noticed")
        return
    await _tap(KEY_E)
    if not GameSession.notebook.knows("mesa_service_tracks"):
        _fail("The outside E press did not record seen machine wear")
        return
    if not GameSession.notebook.related_inferences("mesa_service_tracks").is_empty():
        _fail("Exterior evidence alone claimed to know the inside carrier")
        return

    GameSession.ecology.advance(90.0)
    # physics_frame is emitted BEFORE nodes process that tick; sample after a
    # subsequent tick rather than reading the previous patrol position.
    await get_tree().physics_frame
    await get_tree().physics_frame
    var close_to_hatch: float = worker.global_position.x
    if close_to_hatch < 2360.0 or GameSession.mesa.service_signal_diverted:
        _fail("Curious servitor route: x=%.2f home=%s route=%s elapsed=%.2f" % [
            close_to_hatch, str(worker.get("_home")), str(worker.get("mesa_service_route")),
            GameSession.ecology.elapsed_minutes
        ])
        return
    walker.position = Vector2(325, 320)
    outdoors.call("_sync_chunks")
    await get_tree().process_frame
    if outdoors.get_node_or_null("WorldStreamer/CoolantBasinChunk") != null:
        _fail("Streaming didn't unload the basin")
        return
    walker.position = Vector2(2243, 260)
    outdoors.call("_sync_chunks")
    await get_tree().physics_frame
    worker = outdoors.get_node_or_null("WorldStreamer/CoolantBasinChunk/MesaPryServitor") as CharacterBody2D
    await get_tree().physics_frame
    if worker == null or absf(worker.global_position.x - close_to_hatch) > 3.0:
        _fail("Streaming/reload restarted or rerolled the machine's world-clock route")
        return
    outdoors.queue_free()
    await get_tree().process_frame

    # A separate scene, no shortcut note from opening a new room.
    GameSession.mesa.examine()
    for i: int in range(3):
        GameSession.mesa.turn_handwheel()
    GameSession.mesa.make_first_sector_safe()
    GameSession.mesa.work_power()
    GameSession.mesa.work_power()
    GameSession.current_level = "mesa"
    GameSession.mesa_position = Vector2(1060, 522)
    var mesa_scene := load("res://scenes/interiors/mesa_refuge.tscn") as PackedScene
    var mesa: Node2D = mesa_scene.instantiate() as Node2D
    add_child(mesa)
    var yuna: CharacterBody2D = mesa.get_node("Yuna") as CharacterBody2D
    var panel: MesaCarrierPanel = mesa.get_node_or_null("CarrierPanel") as MesaCarrierPanel
    if panel == null:
        _fail("Interior rear carrier isn't a real physical scene")
        return
    yuna.position = panel.position
    await get_tree().process_frame
    if not str(mesa.call("get_interaction_hint")).contains("dark"):
        _fail("Player can't read the causal pre-circulation condition")
        return
    await _tap(KEY_E)
    if GameSession.mesa.service_signal_inspected or GameSession.notebook.knows("mesa_return_carrier"):
        _fail("E leaked a note through the unrepaired utility lock")
        return
    yuna.position = mesa.FLOW_PANEL
    await get_tree().process_frame
    await _tap(KEY_E)
    await _tap(KEY_E)
    if not GameSession.mesa.flow_online():
        _fail("Real E water repair failed")
        return
    yuna.position = panel.position
    await get_tree().process_frame
    if not str(mesa.call("get_interaction_hint")).contains("Read the repeating"):
        _fail("Live carrier terminal cannot be inspected")
        return
    await _tap(KEY_E)
    if (not GameSession.mesa.service_signal_inspected
            or not GameSession.notebook.knows("mesa_return_carrier")
            or not GameSession.notebook.inference().contains("who sent it")):
        _fail("Live E inspection did not reveal an evidence-based, incomplete hypothesis")
        return
    if not str(mesa.call("get_interaction_hint")).contains("reflector"):
        _fail("Player isn't offered a reversible rerouting choice")
        return
    await _tap(KEY_E)
    if not GameSession.mesa.service_signal_diverted:
        _fail("E did not divert the physical service signal")
        return
    if not str(mesa.call("get_interaction_hint")).contains("Restore the original"):
        _fail("No path to change one's mind")
        return
    if GameSession.mesa.court_restored() or GameSession.mesa.first_night_spent:
        _fail("Optional robot diversion quietly manufactured the story milestone")
        return
    if not GameSession.save_to_disk(TEST_SAVE):
        _fail("Save v16 didn't reach FileAccess")
        return

    mesa.queue_free()
    await get_tree().process_frame
    GameSession.mesa = MesaState.new()
    GameSession.notebook = NotebookState.new()
    if not GameSession.load_from_disk(TEST_SAVE):
        _fail("Real disk load rejected saved service evidence")
        return
    if (not GameSession.mesa.service_signal_diverted
            or not GameSession.mesa.service_signal_inspected
            or GameSession.notebook.inference().find("who sent it") < 0
            or GameSession.current_level != "mesa"):
        _fail("Saved carrier state or learned only-what-Yuna-saw notes lost")
        return

    GameSession.current_level = "outdoors"
    GameSession.outdoor_position = Vector2(2243, 260)
    outdoors = outdoors_scene.instantiate() as Node2D
    add_child(outdoors)
    worker = outdoors.get_node_or_null("WorldStreamer/CoolantBasinChunk/MesaPryServitor") as CharacterBody2D
    await get_tree().physics_frame
    if worker == null or worker.global_position.x > 2310.0:
        _fail("After v16 disk load the servitor didn't follow the diverted line")
        return
    outdoors.queue_free()
    await get_tree().process_frame

    GameSession.current_level = "mesa"
    mesa = mesa_scene.instantiate() as Node2D
    add_child(mesa)
    panel = mesa.get_node("CarrierPanel") as MesaCarrierPanel
    yuna = mesa.get_node("Yuna") as CharacterBody2D
    yuna.position = panel.position
    await get_tree().process_frame
    await _tap(KEY_E)
    if GameSession.mesa.service_signal_diverted:
        _fail("Re-entry E couldn't return the maintenance robot to original route")
        return
    mesa.queue_free()
    await get_tree().process_frame

    DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
    _restore_player_save()
    print("PASS: exterior machine marks, timed world-clock patrol, real E carrier, reversible robot route and v16 disk/stream reentry")
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
    Input.action_release("interact")
    if _had_save:
        var save: FileAccess = FileAccess.open(GameSession.SAVE_PATH, FileAccess.WRITE)
        if save != null:
            save.store_buffer(_save_bytes)
            save.close()
    elif FileAccess.file_exists(GameSession.SAVE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSession.SAVE_PATH))


func _fail(reason: String) -> void:
    _restore_player_save()
    push_error("P4e service signal scene: " + reason)
    get_tree().quit(1)
