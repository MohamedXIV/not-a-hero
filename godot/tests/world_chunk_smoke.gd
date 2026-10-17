extends SceneTree
## Run with: godot --headless --path godot --script res://tests/world_chunk_smoke.gd
## Exercises chunk reload state and asserts *scene structure*, not visual FPS.


func _initialize() -> void:
    call_deferred("_check")


func _check() -> void:
    var outdoors_scene: PackedScene = load("res://scenes/world/outdoors.tscn") as PackedScene
    if outdoors_scene == null:
        push_error("Missing outdoors scene")
        quit(1)
        return
    var outdoors: Node2D = outdoors_scene.instantiate() as Node2D
    root.add_child(outdoors)
    # P0 start loads chunk 0 and chunk 1.
    var relay: Node2D = outdoors.get_node_or_null("AshFlatsChunk/RelaySwitch") as Node2D
    _assert_ok(relay != null, "relay node initially loaded")
    relay.call("interact")
    _assert_ok(GameSession.get_world_flag(&"world/ash_flats/relay_01"), "relay world flag set")
    var yuna: CharacterBody2D = outdoors.get_node("Yuna") as CharacterBody2D
    yuna.position = Vector2(1500, 280)
    outdoors.call("_sync_chunks")
    _assert_ok(outdoors.get_node_or_null("AshFlatsChunk") == null or outdoors.get_node("AshFlatsChunk").is_queued_for_deletion(), "far chunk retired")
    yuna.position = Vector2(160, 330)
    # Pending deletion can coexist for one frame, so the follow-up check needs to wait.
    await process_frame
    outdoors.call("_sync_chunks")
    await process_frame
    relay = outdoors.get_node_or_null("AshFlatsChunk/RelaySwitch") as Node2D
    _assert_ok(relay != null, "chunk returned")
    _assert_ok(relay.get("is_active"), "relay remains on after unload/reload")
    outdoors.queue_free()
    print("PASS: authored chunk lifecycle and persistent relay interaction")
    quit(0)


func _assert_ok(condition: bool, label: String) -> void:
    if not condition:
        push_error("FAIL: " + label)
        quit(1)
        assert(condition, label)
