extends Node
## P3b engine smoke: four seamless authored chunks, two new physical
## observations, streaming and no second loot drop after revisiting the basin.

const DEFS: Array[Resource] = [
    preload("res://resources/world/chunks/ash_flats.tres"),
    preload("res://resources/world/chunks/cable_edge.tres"),
    preload("res://resources/world/chunks/relay_waste.tres"),
    preload("res://resources/world/chunks/coolant_basin.tres"),
]


func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    var regions: Array[String] = []
    for cell: int in range(4):
        var part: WorldChunkDefinition = DEFS[cell] as WorldChunkDefinition
        if part.grid_cell != Vector2i(cell, 0) or part.scene == null:
            _fail("Found a gap or missing authored chunk at %d" % cell)
            return
        regions.append(String(part.region_id))
    if regions != ["ash_flats", "cable_forest", "dead_foundry", "coolant_basin"]:
        _fail("Unexpected machine biome identities: " + str(regions))
        return

    GameSession.current_level = "outdoors"
    GameSession.outdoor_position = Vector2(160, 330)
    GameSession.bag = InventoryState.new()
    GameSession.voice = YunaVoice.new()
    GameSession.notebook = NotebookState.new()
    GameSession.world_seed = 20261017
    GameSession.set_world_flag(&"world/coolant_basin/filter_cache_01", false)
    var world: Node2D = (load("res://scenes/world/outdoors.tscn") as PackedScene).instantiate() as Node2D
    add_child(world)
    var yuna: CharacterBody2D = world.get_node("Yuna") as CharacterBody2D
    var camera: Camera2D = yuna.get_node("Camera2D") as Camera2D
    if camera.limit_right != 2560:
        _fail("Camera clips the new fourth biome")
        return
    if world.get_node_or_null("WorldStreamer/CoolantBasinChunk") != null:
        _fail("Coolant biome loaded too early")
        return

    yuna.position = Vector2(1630, 375)
    world.call("_sync_chunks")
    await get_tree().process_frame
    var press: Node2D = world.get_node_or_null("WorldStreamer/RelayWasteChunk/AutonomousPress") as Node2D
    if press == null:
        _fail("Foundry press evidence missing at authored site")
        return
    world.call("_try_interaction")
    if not GameSession.notebook.knows("foundry_shift_cycle"):
        _fail("Investigating press failed to record first witnessed fact")
        return
    if GameSession.notebook.knows("basin_reverse_flow") or not GameSession.notebook.inference().is_empty():
        _fail("Notebook guessed unknown basin evidence")
        return

    yuna.position = Vector2(2058, 426)
    world.call("_sync_chunks")
    await get_tree().process_frame
    var siphon: Node2D = world.get_node_or_null("WorldStreamer/CoolantBasinChunk/ReverseFlowSiphon") as Node2D
    var worker: CharacterBody2D = world.get_node_or_null("WorldStreamer/CoolantBasinChunk/CoolantServitor") as CharacterBody2D
    var cache: Node2D = world.get_node_or_null("WorldStreamer/CoolantBasinChunk/FilterCache") as Node2D
    if siphon == null or worker == null or cache == null:
        _fail("Coolant scene lacks authored landmark, cache or passive machine")
        return
    if worker.has_method("receive_damage") or worker.has_method("attack"):
        _fail("Coolant servitor unexpectedly exposes hostile attack behavior")
        return
    world.call("_try_interaction")
    if not GameSession.notebook.knows("basin_reverse_flow"):
        _fail("Investigating siphon failed to record second witnessed fact")
        return
    if not GameSession.notebook.inference().contains("press and the siphon"):
        _fail("Independent foundry/basin facts didn't combine into a tentative inference")
        return
    if GameSession.notebook.knows("ash_warm_conduit") or GameSession.notebook.knows("cable_scarred_junction"):
        _fail("Fourth biome leaked early-world knowledge")
        return

    yuna.position = Vector2(1912, 348)
    world.call("_sync_chunks")
    Input.action_press("move_right")
    for i: int in range(12):
        await get_tree().physics_frame
    Input.action_release("move_right")
    if yuna.position.x <= 1924.0:
        _fail("Player couldn't walk across Foundry-Coolant seam")
        return
    yuna.position = Vector2(2452, 504)
    if not cache.call("interact"):
        _fail("Coolant biome loot wasn't collectible")
        return
    var loot_state: Dictionary = GameSession.bag.snapshot()
    if loot_state.is_empty() or not GameSession.get_world_flag(&"world/coolant_basin/filter_cache_01"):
        _fail("Filter salvage wasn't persisted")
        return

    yuna.position = Vector2(160, 330)
    world.call("_sync_chunks")
    await get_tree().process_frame
    if world.get_node_or_null("WorldStreamer/CoolantBasinChunk") != null:
        _fail("Distant basin scene did not unload")
        return
    yuna.position = Vector2(2452, 504)
    world.call("_sync_chunks")
    await get_tree().process_frame
    cache = world.get_node_or_null("WorldStreamer/CoolantBasinChunk/FilterCache") as Node2D
    if cache == null or not bool(cache.get("looted")) or cache.call("interact"):
        _fail("Returning to basin regenerated looted filter cache")
        return
    if GameSession.bag.snapshot() != loot_state:
        _fail("Basin revisit duplicated salvage")
        return
    var captured: Dictionary = GameSession.snapshot()
    GameSession.notebook = NotebookState.new()
    if not GameSession.restore_snapshot(captured) or not GameSession.notebook.knows("basin_reverse_flow"):
        _fail("New-region observation did not survive save snapshot")
        return
    if GameSession.snapshot() != captured:
        _fail("Loaded world facts differ from original save")
        return
    Input.action_release("move_right")
    world.queue_free()
    print("PASS: contiguous four-region traversal, real evidence, passive servitor and persistent basin salvage")
    get_tree().quit(0)


func _fail(message: String) -> void:
    Input.action_release("move_right")
    push_error("P3b world regions failure: " + message)
    get_tree().quit(1)
