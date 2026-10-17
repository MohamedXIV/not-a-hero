extends Node
## Check real Godot CharacterBody2D movement and collision before visual approval.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")


func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    GameSession.current_level = "shelter"
    GameSession.shelter_position = Vector2(340, 365)
    var main: Node2D = MAIN_SCENE.instantiate() as Node2D
    add_child(main)
    var shelter: Node2D = main.get("_level") as Node2D
    if shelter == null:
        _fail("shelter failed to instantiate")
        return
    var yuna: CharacterBody2D = shelter.get_node("Yuna") as CharacterBody2D
    var camera: Camera2D = yuna.get_node("Camera2D") as Camera2D
    if camera.zoom.x < 1.7:
        _fail("interior camera is not the close view")
        return

    var start_x: float = yuna.position.x
    Input.action_press("move_right")
    for i: int in range(10):
        await get_tree().physics_frame
    Input.action_release("move_right")
    if yuna.position.x < start_x + 15.0:
        _fail("WASD movement did not advance Yuna")
        return

    # A bed must obstruct her feet rather than letting her walk through it.
    yuna.position = Vector2(230, 200)
    Input.action_press("move_left")
    for i: int in range(20):
        await get_tree().physics_frame
    Input.action_release("move_left")
    if yuna.position.x < 214:
        _fail("Yuna phased through the bed collider")
        return

    main.call("_open_level", "outdoors")
    if shelter.is_inside_tree():
        _fail("previous shelter remains active after scene switch")
        return
    await get_tree().process_frame
    var outside: Node2D = main.get("_level") as Node2D
    if outside == null:
        _fail("outdoor scene failed to instantiate")
        return
    yuna = outside.get_node("Yuna") as CharacterBody2D
    yuna.position = Vector2(628, 330)
    Input.action_press("move_right")
    for i: int in range(12):
        await get_tree().physics_frame
    Input.action_release("move_right")
    if yuna.position.x < 646:
        _fail("Yuna failed to walk over the authored chunk seam")
        return
    if outside.get_node_or_null("WorldStreamer/RelayWasteChunk") == null:
        _fail("next chunk was not preloaded as Yuna crossed the seam")
        return
    if outside.get_node_or_null("WorldStreamer/AshFlatsChunk") == null:
        _fail("origin chunk vanished too early at first seam")
        return

    print("PASS: Yuna movement, bed collision, camera zoom and seam crossing")
    main.queue_free()
    get_tree().quit(0)


func _fail(message: String) -> void:
    Input.action_release("move_left")
    Input.action_release("move_right")
    push_error("Movement smoke failure: " + message)
    get_tree().quit(1)
