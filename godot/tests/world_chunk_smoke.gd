extends Node
## Run as a scene; this initializes GameSession and InputMap as in the real game.

func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"interact", &"sprint", &"quick_save"]:
        if not InputMap.has_action(action):
            _fail("Missing input at boot: " + String(action))
            return
    GameSession.outdoor_position = Vector2(160, 330)
    GameSession.set_world_flag(&"world/ash_flats/relay_01", false)
    var scene: PackedScene = load("res://scenes/world/outdoors.tscn") as PackedScene
    var outdoors: Node2D = scene.instantiate() as Node2D
    add_child(outdoors)

    var streamer: Node2D = outdoors.get_node("WorldStreamer") as Node2D
    if streamer.call("active_chunk_count") != 2:
        _fail("two neighboring authored chunks should be loaded")
        return
    var relay: Node2D = outdoors.get_node_or_null("WorldStreamer/AshFlatsChunk/RelaySwitch") as Node2D
    if relay == null:
        _fail("relay missing from authored origin chunk")
        return
    relay.call("interact")
    if not GameSession.get_world_flag(&"world/ash_flats/relay_01"):
        _fail("relay did not change the authoritative world")
        return
    var yuna: CharacterBody2D = outdoors.get_node("Yuna") as CharacterBody2D
    yuna.position = Vector2(1500, 280)
    outdoors.call("_sync_chunks")
    await get_tree().process_frame
    if outdoors.get_node_or_null("WorldStreamer/AshFlatsChunk") != null:
        _fail("distant chunk not unloaded")
        return
    yuna.position = Vector2(160, 330)
    outdoors.call("_sync_chunks")
    await get_tree().process_frame
    relay = outdoors.get_node_or_null("WorldStreamer/AshFlatsChunk/RelaySwitch") as Node2D
    if relay == null or not relay.get("is_active"):
        _fail("relay didn't restore after chunk unload/reload")
        return
    print("PASS: authored chunk Resources, lifecycle and persistent relay state")
    outdoors.queue_free()
    get_tree().quit(0)


func _fail(message: String) -> void:
    push_error("FAIL: " + message)
    get_tree().quit(1)
