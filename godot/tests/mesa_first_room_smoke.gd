extends Node
## Tests the distinct sun-court scene and personal safety control. This test
## explicitly does not claim the outdoor-to-interior transition is connected.

func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    GameSession.mesa = MesaState.new()
    GameSession.mesa.examine()
    for i: int in range(3):
        GameSession.mesa.turn_handwheel()
    GameSession.current_level = "mesa"
    GameSession.mesa_position = Vector2(232, 555)
    var packed: PackedScene = load("res://scenes/interiors/mesa_refuge.tscn") as PackedScene
    var level: Node2D = packed.instantiate() as Node2D
    add_child(level)
    var yuna: CharacterBody2D = level.get_node("Yuna") as CharacterBody2D
    var camera: Camera2D = yuna.get_node("Camera2D") as Camera2D
    if camera.limit_right != 1280 or yuna.position != GameSession.mesa_position:
        _fail("Larger mesa is not a separate authored room with saved Yuna position")
        return
    if GameSession.mesa.first_sector_safe:
        _fail("Newly opened refuge cannot start safe")
        return
    yuna.position = level.SAFETY_PANEL
    if not str(level.call("get_interaction_hint")).contains("Isolate"):
        _fail("Physical sector safety panel is not discoverable")
        return
    level.call("_interact_nearby")
    if not GameSession.mesa.first_sector_safe:
        _fail("Actual panel didn't make the first sector safe")
        return
    var saved: Dictionary = GameSession.snapshot()
    var clone: Node = (load("res://scripts/core/game_session.gd") as GDScript).new() as Node
    if not clone.call("restore_snapshot", saved) or not (clone.get("mesa") as MesaState).first_sector_safe:
        _fail("Sector safety and distinct room location not saved")
        clone.free()
        return
    clone.free()
    var signaled: Array[String] = []
    level.transition_requested.connect(func(dest: String) -> void: signaled.append(dest))
    yuna.position = level.EXIT_POINT
    level.call("_interact_nearby")
    if signaled != ["outdoors"] or GameSession.outdoor_position != Vector2(2420, 172):
        _fail("Mesa doesn't return safely to its own outside door")
        return
    level.queue_free()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSession.SAVE_PATH))
    print("PASS: large distinct sun-court scene, one-time safety activation, saved state and exit route")
    get_tree().quit(0)


func _fail(message: String) -> void:
    push_error("P4a interior failure: " + message)
    get_tree().quit(1)
