extends Node
## The real Foundry maintenance site spawns a harmless crew during a shift,
## yields just one physical spare part and doesn't reset on streamed reload.

func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    GameSession.current_level = "outdoors"
    GameSession.outdoor_position = Vector2(160.0, 330.0)
    GameSession.world_seed = 20261017
    GameSession.bag = InventoryState.new()
    GameSession.ecology = MachineEcology.new()
    var found: bool = false
    for i: int in range(36):
        if GameSession.ecology.is_active("dead_foundry", GameSession.world_seed):
            found = true
            break
        GameSession.ecology.advance(360.0)
    if not found:
        _fail("Couldn't find deterministic maintenance shift")
        return
    var world: Node2D = (load("res://scenes/world/outdoors.tscn") as PackedScene).instantiate() as Node2D
    add_child(world)
    var yuna: CharacterBody2D = world.get_node("Yuna") as CharacterBody2D
    yuna.position = Vector2(1820, 155)
    world.call("_sync_chunks")
    await get_tree().process_frame
    var site: Node2D = world.get_node_or_null("WorldStreamer/RelayWasteChunk/ReclaimerShift") as Node2D
    if site == null or not site.get("_working"):
        _fail("Foundry shift was not instantiated as active after offscreen time passed")
        return
    if site.get_child_count() != 1:
        _fail("Maintenance shift did not spawn a physical neutral worker")
        return
    var worker: Node = site.get_child(0)
    if worker.is_in_group("robot_sensors") or worker.has_method("take_damage"):
        _fail("Maintenance shift worker incorrectly became hostile")
        return
    var before: int = GameSession.bag.quantity(&"alloy")
    world.call("_try_interaction")
    if GameSession.bag.quantity(&"alloy") != before + 1:
        _fail("Real in-world maintenance interaction didn't provide one spare part")
        return
    world.call("_try_interaction")
    if GameSession.bag.quantity(&"alloy") != before + 1:
        _fail("Repeated interaction duplicated maintenance salvage")
        return
    var record: Dictionary = GameSession.snapshot()
    if not GameSession.save_to_disk("user://nah_ecology_test.json"):
        _fail("Machine events failed real disk save")
        return

    yuna.position = Vector2(100, 330)
    world.call("_sync_chunks")
    await get_tree().process_frame
    if world.get_node_or_null("WorldStreamer/RelayWasteChunk") != null:
        _fail("Distant Foundry chunk should unload")
        return
    yuna.position = Vector2(1820, 155)
    world.call("_sync_chunks")
    await get_tree().process_frame
    site = world.get_node_or_null("WorldStreamer/RelayWasteChunk/ReclaimerShift") as Node2D
    if site == null or GameSession.ecology.can_collect("dead_foundry", GameSession.world_seed):
        _fail("Re-streaming the Foundry reset an already collected shift")
        return
    GameSession.ecology = MachineEcology.new()
    if not GameSession.load_from_disk("user://nah_ecology_test.json"):
        _fail("Machine ecology wasn't restored by FileAccess")
        return
    if GameSession.snapshot() != record:
        _fail("Full saved session changed after ecology reload")
        return
    if GameSession.ecology.can_collect("dead_foundry", GameSession.world_seed):
        _fail("Disk reload incorrectly restored uncollected event")
        return

    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://nah_ecology_test.json"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSession.SAVE_PATH))
    print("PASS: physical neutral Foundry shift, once-per-epoch salvage, stream unload and disk reload")
    world.queue_free()
    get_tree().quit(0)


func _fail(message: String) -> void:
    push_error("Machine ecology scene failure: " + message)
    get_tree().quit(1)
