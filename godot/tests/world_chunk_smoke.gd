extends Node
## Run this test as a scene so the project's registered GameSession autoload is active:
## godot --headless --path godot res://tests/world_chunk_smoke.tscn --quit-after 180


func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    GameSession.current_level = "outdoors"
    GameSession.outdoor_position = Vector2(160.0, 330.0)
    GameSession.set_world_flag(&"world/ash_flats/relay_01", false)

    var packed: PackedScene = load("res://scenes/world/outdoors.tscn") as PackedScene
    if packed == null:
        _fail("outdoors scene missing")
        return
    var outdoors: Node2D = packed.instantiate() as Node2D
    add_child(outdoors)
    var relay: Node2D = outdoors.get_node_or_null("AshFlatsChunk/RelaySwitch") as Node2D
    if relay == null:
        _fail("relay node was not loaded in starting chunk")
        return

    relay.call("interact")
    if not GameSession.get_world_flag(&"world/ash_flats/relay_01"):
        _fail("relay activation did not persist in authoritative world state")
        return

    var yuna: CharacterBody2D = outdoors.get_node("Yuna") as CharacterBody2D
    yuna.position = Vector2(1500.0, 280.0)
    outdoors.call("_sync_chunks")
    await get_tree().process_frame
    if outdoors.get_node_or_null("AshFlatsChunk") != null:
        _fail("far chunk should have been removed")
        return

    yuna.position = Vector2(160.0, 330.0)
    outdoors.call("_sync_chunks")
    await get_tree().process_frame
    relay = outdoors.get_node_or_null("AshFlatsChunk/RelaySwitch") as Node2D
    if relay == null or not relay.get("is_active"):
        _fail("returning to authored chunk did not restore relay")
        return

    print("PASS: continuous authored chunks unload and restore persistent relay state")
    outdoors.queue_free()
    get_tree().quit(0)


func _fail(message: String) -> void:
    push_error("FAIL: " + message)
    get_tree().quit(1)
