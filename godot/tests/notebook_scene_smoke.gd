extends Node
## Real inspectable world markers + streaming persistence + notebook HUD.

func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    GameSession.current_level = "outdoors"
    GameSession.outdoor_position = Vector2(160, 330)
    GameSession.notebook = NotebookState.new()
    GameSession.voice = YunaVoice.new()
    var world_scene: PackedScene = load("res://scenes/world/outdoors.tscn") as PackedScene
    var outdoors: Node2D = world_scene.instantiate() as Node2D
    add_child(outdoors)
    var yuna: CharacterBody2D = outdoors.get_node("Yuna") as CharacterBody2D
    var ash: Node2D = outdoors.get_node_or_null("WorldStreamer/AshFlatsChunk/BuriedConduit") as Node2D
    var cable: Node2D = outdoors.get_node_or_null("WorldStreamer/CableEdgeChunk/ScuffedJunction") as Node2D
    if ash == null or cable == null:
        _fail("Authored world observations are not instantiated")
        return

    # Deliberately inspect Cable Forest FIRST. No pre-baked quest order.
    yuna.position = cable.global_position
    outdoors.call("_try_interaction")
    if not GameSession.notebook.knows("cable_scarred_junction"):
        _fail("World inspection didn't create its observed note")
        return
    if GameSession.notebook.knows("ash_warm_conduit") or not GameSession.notebook.inference().is_empty():
        _fail("Notebook leaked a hidden Ash Flats clue")
        return
    yuna.position = ash.global_position
    outdoors.call("_try_interaction")
    if not GameSession.notebook.knows("ash_warm_conduit") or GameSession.notebook.inference().is_empty():
        _fail("Second independent world observation didn't produce inference")
        return
    if GameSession.notebook.observed_ids()[0] != "cable_scarred_junction":
        _fail("Notebook should preserve discovery order")
        return
    outdoors.call("_try_interaction")
    if GameSession.notebook.observed_ids().size() != 2:
        _fail("Repeated examination duplicated entries")
        return

    yuna.position = Vector2(1790, 280)
    outdoors.call("_sync_chunks")
    await get_tree().process_frame
    if outdoors.get_node_or_null("WorldStreamer/AshFlatsChunk") != null:
        _fail("Leaving region didn't unload its scene")
        return
    yuna.position = Vector2(160, 330)
    outdoors.call("_sync_chunks")
    await get_tree().process_frame
    ash = outdoors.get_node_or_null("WorldStreamer/AshFlatsChunk/BuriedConduit") as Node2D
    if ash == null or not str(ash.call("get_interaction_label")).contains("Re-examine"):
        _fail("Revisited clue lost observed state")
        return
    var recorded: Dictionary = GameSession.snapshot()
    GameSession.notebook = NotebookState.new()
    if not GameSession.restore_snapshot(recorded) or GameSession.notebook.observed_ids().size() != 2:
        _fail("Notebook knowledge didn't survive saved state")
        return
    outdoors.queue_free()

    # The player can actually open and read the UI; it cannot show unknown notes.
    var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node2D
    add_child(main)
    var label: Label = main.get("_notebook_display") as Label
    if label == null:
        _fail("Player's notebook panel missing")
        return
    label.visible = true
    main.call("_update_notebook_display")
    if not label.text.contains("YUNA'S NOTEBOOK") or not label.text.contains("Cable"):
        _fail("Notebook HUD failed to display known evidence")
        return
    DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSession.SAVE_PATH))
    print("PASS: real inspection order, conditional notebook, chunk reload and saved discovery UI")
    main.queue_free()
    get_tree().quit(0)


func _fail(message: String) -> void:
    push_error("Discovery scene smoke: " + message)
    get_tree().quit(1)
