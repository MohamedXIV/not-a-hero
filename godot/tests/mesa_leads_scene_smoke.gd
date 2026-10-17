extends Node
## Two playable observation orders in the real continuous world; no other
## observations, combat, RNG event or quest objective is required.

func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    GameSession.current_level = "outdoors"
    GameSession.outdoor_position = Vector2(320, 320)
    GameSession.notebook = NotebookState.new()
    GameSession.voice = YunaVoice.new()
    var outdoor: Node2D = (load("res://scenes/world/outdoors.tscn") as PackedScene).instantiate() as Node2D
    add_child(outdoor)
    var yuna: CharacterBody2D = outdoor.get_node("Yuna") as CharacterBody2D

    # Approach A: inspect the cable feeder BEFORE the warmer Ash Flats cable.
    if not await _inspect(outdoor, yuna, Vector2(1175, 460), "EastboundFeeder", "CableEdgeChunk", "cable_eastbound_feeder"):
        return
    if not GameSession.notebook.mesa_leads().is_empty():
        _fail("New feeder alone revealed the mesa hypothesis")
        return
    if not await _inspect(outdoor, yuna, Vector2(325, 320), "BuriedConduit", "AshFlatsChunk", "ash_warm_conduit"):
        return
    if GameSession.notebook.mesa_leads() != ["eastern_power"]:
        _fail("Power discoveries didn't create a viable independent east-shelf lead")
        return
    if GameSession.notebook.knows("basin_return_manifold"):
        _fail("Power route guessed the unseen basin marker")
        return

    # Approach B: independent journal; Basin FIRST, then Foundry, no Ash/Cable.
    GameSession.notebook = NotebookState.new()
    if not await _inspect(outdoor, yuna, Vector2(2476, 270), "BuriedReturnManifold", "CoolantBasinChunk", "basin_return_manifold"):
        return
    if not GameSession.notebook.mesa_leads().is_empty():
        _fail("Return manifold alone revealed the mesa hypothesis")
        return
    if not await _inspect(outdoor, yuna, Vector2(1605, 375), "AutonomousPress", "RelayWasteChunk", "foundry_shift_cycle"):
        return
    if GameSession.notebook.mesa_leads() != ["eastern_service"]:
        _fail("Service discoveries didn't create an independent east-shelf lead")
        return
    if GameSession.notebook.knows("ash_warm_conduit"):
        _fail("Mechanical route fabricated an unseen Ash Flats clue")
        return

    var saved: Dictionary = GameSession.snapshot()
    if not GameSession.save_to_disk("user://nah_p3d_mesa_leads.json"):
        _fail("Couldn't save world-clue observations")
        return
    GameSession.notebook = NotebookState.new()
    if not GameSession.load_from_disk("user://nah_p3d_mesa_leads.json"):
        _fail("Observed lead state couldn't be restored from file")
        return
    if GameSession.notebook.mesa_leads() != ["eastern_service"]:
        _fail("Service route knowledge was lost after disk reload: %s" % str(GameSession.notebook.mesa_leads()))
        return
    # JSON encodes all numbers as JSON number; Godot's loader then restores
    # typed ints and other normalized states. Compare the FULL restored state
    # against a separate independently restored baseline, not the raw JSON.
    var canonical_saved: Dictionary = JSON.parse_string(JSON.stringify(saved)) as Dictionary
    var check_session: Node = (load("res://scripts/core/game_session.gd") as GDScript).new() as Node
    if not check_session.call("restore_snapshot", canonical_saved):
        _fail("Canonical disk save could not restore into independent session")
        check_session.free()
        return
    var expected: Dictionary = check_session.call("snapshot")
    check_session.free()
    if GameSession.snapshot() != expected:
        var after: Dictionary = GameSession.snapshot()
        for key: Variant in expected.keys():
            if after.get(key) != expected[key]:
                print("DIAGNOSTIC: normalized save field changed on reload: %s; before=%s; after=%s" % [
                    str(key), str(expected[key]).left(550), str(after.get(key)).left(550)
                ])
        _fail("Session fields differ after canonical mesa lead disk reload")
        return

    yuna.position = Vector2(325, 320)
    outdoor.call("_sync_chunks")
    await get_tree().process_frame
    if outdoor.get_node_or_null("WorldStreamer/CoolantBasinChunk") != null:
        _fail("Basin chunk stayed loaded at the start of the world")
        return
    yuna.position = Vector2(2476, 270)
    outdoor.call("_sync_chunks")
    await get_tree().process_frame
    var marker: Node2D = outdoor.get_node_or_null("WorldStreamer/CoolantBasinChunk/BuriedReturnManifold") as Node2D
    if marker == null or not str(marker.call("get_interaction_label")).contains("Re-examine"):
        _fail("Streamed return manifold did not remember its discovered state")
        return

    outdoor.queue_free()
    await get_tree().process_frame
    var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node2D
    add_child(main)
    var ui: Label = main.get("_notebook_display") as Label
    if ui == null:
        _fail("Main scene has no notebook panel")
        return
    ui.visible = true
    main.call("_update_notebook_display")
    if (not ui.text.contains("Connections I can make")
            or not ui.text.contains("eastern shelf")
            or ui.text.contains("warm conduit")):
        _fail("Notebook page didn't show relevant service deduction only")
        return
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://nah_p3d_mesa_leads.json"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSession.SAVE_PATH))
    print("PASS: two independently playable mesa leads, no unseen knowledge, scene streaming and disk/UI persistence")
    main.queue_free()
    get_tree().quit(0)


func _inspect(world: Node2D, player: CharacterBody2D, position: Vector2,
        marker_name: String, chunk_name: String, id: String) -> bool:
    player.position = position
    world.call("_sync_chunks")
    await get_tree().process_frame
    var observed: Node2D = world.get_node_or_null("WorldStreamer/%s/%s" % [chunk_name, marker_name]) as Node2D
    if observed == null:
        _fail("Authored clue is missing from the world: " + id)
        return false
    world.call("_try_interaction")
    if not GameSession.notebook.knows(id):
        _fail("Couldn't physically inspect evidence: " + id)
        return false
    return true


func _fail(message: String) -> void:
    push_error("Mesa lead scene failure: " + message)
    get_tree().quit(1)
