extends Node
## Tests actual authored mesa exterior, scene objects, first-sector care and
## retention of both shelters. The separate mesa_player_route_smoke exercises E/Q dispatch.

const TEST_SAVE: String = "user://nah_p4a_site_homes_test.json"

var _had_player_save: bool = false
var _original_player_bytes: PackedByteArray


func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    # Actual interactions autosave to GameSession.SAVE_PATH. Preserve any
    # existing local save so the test is safe to run outside ephemeral CI.
    _had_player_save = FileAccess.file_exists(GameSession.SAVE_PATH)
    if _had_player_save:
        _original_player_bytes = FileAccess.get_file_as_bytes(GameSession.SAVE_PATH)
    GameSession.current_level = "outdoors"
    GameSession.outdoor_position = Vector2(160, 330)
    GameSession.mesa = MesaState.new()
    GameSession.notebook = NotebookState.new() # no clue gate
    GameSession.bag = InventoryState.new()
    GameSession.decor = ShelterDecorState.new()
    if not GameSession.bag.try_receive({"relay_fuse": 1, "rug": 1}):
        _fail("Couldn't prepare test items")
        return
    var outdoors := (load("res://scenes/world/outdoors.tscn") as PackedScene).instantiate() as Node2D
    add_child(outdoors)
    var yuna := outdoors.get_node("Yuna") as CharacterBody2D
    yuna.position = Vector2(2420, 172)
    outdoors.call("_sync_chunks")
    await get_tree().process_frame

    var hatch: Node2D = outdoors.get_node_or_null(
        "WorldStreamer/CoolantBasinChunk/MesaEntrance"
    ) as Node2D
    var pryer: Node2D = outdoors.get_node_or_null(
        "WorldStreamer/CoolantBasinChunk/MesaPryServitor"
    ) as Node2D
    if hatch == null or pryer == null:
        _fail("Physical mesa entrance or curious machine missing from Basin")
        return
    if not str(hatch.call("get_interaction_label")).contains("Examine"):
        _fail("A fresh, uninspected hatch is not legible")
        return
    if not bool(hatch.call("interact")) or not GameSession.mesa.inspected:
        _fail("Inspecting the actual entrance must establish the physical fact")
        return

    # No prior notebook evidence, no fight and no randomly selected key.
    var before_fuse: int = GameSession.bag.quantity(&"relay_fuse")
    if not bool(hatch.call("install_fuse")) or not GameSession.mesa.is_open():
        _fail("The hatch's optional fuse access path didn't work")
        return
    if GameSession.bag.quantity(&"relay_fuse") != before_fuse - 1:
        _fail("Real entrance didn't consume exactly one fuse")
        return
    if not str(hatch.call("get_interaction_label")).contains("Enter"):
        _fail("Opened entrance didn't advertise where to go")
        return

    # Same actual physical hatch must also accept the slower material-free
    # handwheel path; no Notebook lead or combat prerequisite.
    var fuse_snapshot: Dictionary = GameSession.mesa.snapshot()
    GameSession.mesa = MesaState.new()
    if not bool(hatch.call("interact")):
        _fail("Real door could not be inspected for manual access")
        return
    for stage: int in range(MesaState.MANUAL_STAGES):
        if not bool(hatch.call("interact")):
            _fail("Real handwheel refused stage %d" % stage)
            return
    if not GameSession.mesa.is_open() or GameSession.mesa.access_method != "manual":
        _fail("The physical handwheel did not open the door")
        return
    if not GameSession.mesa.restore_snapshot(fuse_snapshot):
        _fail("Couldn't reset door to retained fuse-route state for save test")
        return

    GameSession.current_level = "mesa"
    var large := (load("res://scenes/interiors/mesa_refuge.tscn") as PackedScene).instantiate() as Node2D
    add_child(large)
    var mesa_yuna := large.get_node("Yuna") as CharacterBody2D
    mesa_yuna.position = large.SAFETY_PANEL
    large.call("_interact_nearby")
    if not GameSession.mesa.first_sector_safe:
        _fail("Real mesa interior couldn't be secured after entry")
        return
    var out_signals: Array[String] = []
    large.transition_requested.connect(func(target: String) -> void: out_signals.append(target))
    mesa_yuna.position = large.EXIT_POINT
    large.call("_interact_nearby")
    if out_signals != ["outdoors"] or GameSession.outdoor_position != Vector2(2420, 172):
        _fail("Mesa exit wasn't reversible back to the correct world position")
        return
    large.queue_free()
    outdoors.queue_free()
    await get_tree().process_frame

    GameSession.current_level = "shelter"
    var home := (load("res://scenes/interiors/starter_shelter.tscn") as PackedScene).instantiate() as Node2D
    add_child(home)
    var decorator: Node2D = home.get_node("ShelterDecorator") as Node2D
    if not bool(decorator.call("place_at", "rug", Vector2(448, 384))):
        _fail("Couldn't furnish the independent original home")
        return
    if GameSession.decor.count_kind("rug") != 1:
        _fail("Original home's decor state changed after mesa visit")
        return
    var home_point: Vector2 = GameSession.shelter_position
    var note_count: int = GameSession.notebook.observed_ids().size()
    if not GameSession.save_to_disk(TEST_SAVE):
        _fail("Couldn't persist both refuges to disk")
        return
    home.queue_free()
    await get_tree().process_frame

    GameSession.mesa = MesaState.new()
    GameSession.decor = ShelterDecorState.new()
    GameSession.current_level = "outdoors"
    if not GameSession.load_from_disk(TEST_SAVE):
        _fail("Couldn't restore both refuges from real FileAccess JSON")
        return
    if (not GameSession.mesa.first_sector_safe or GameSession.mesa.access_method != "fuse"
            or GameSession.decor.count_kind("rug") != 1
            or GameSession.shelter_position != home_point
            or GameSession.notebook.observed_ids().size() != note_count):
        _fail("Restoring mesa overwrote original home or other saved facts")
        return
    if GameSession.current_level != "shelter":
        _fail("Saved level doesn't preserve the original Little Nest as home")
        return
    # Also demonstrate a valid alternative manual path from an independent
    # fresh model; neither path depends on knowing the mesa notebook leads.
    var manual := MesaState.new()
    if not manual.examine():
        _fail("Manual route inspection failed")
        return
    for i: int in range(3):
        if not manual.turn_handwheel():
            _fail("Manual handwheel stage failed")
            return
    if not manual.is_open() or manual.access_method != "manual":
        _fail("Manual access not possible without materials")
        return

    DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
    _restore_player_save()
    print("PASS: physical mesa entrance, both entry mechanisms, room safety, reversible exit and two saved homes")
    get_tree().quit(0)


func _restore_player_save() -> void:
    if _had_player_save:
        var out: FileAccess = FileAccess.open(GameSession.SAVE_PATH, FileAccess.WRITE)
        if out != null:
            out.store_buffer(_original_player_bytes)
            out.close()
    elif FileAccess.file_exists(GameSession.SAVE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSession.SAVE_PATH))


func _fail(message: String) -> void:
    _restore_player_save()
    push_error("Mesa site/homes smoke: " + message)
    get_tree().quit(1)
