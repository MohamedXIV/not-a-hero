extends Node
## Author-only comparison uses one real player with unchanged collider/camera,
## shared physical occluder, practical dynamic lamp and identical world geometry.
## No saved-game changes and no art style silently committed to main gameplay.


func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    GameSession.current_level = "shelter"
    var study := (load("res://scenes/presentation/visual_study.tscn") as PackedScene).instantiate() as Node2D
    add_child(study)
    var player: CharacterBody2D = study.get_node("Yuna") as CharacterBody2D
    var cam: Camera2D = player.get_node("Camera2D") as Camera2D
    if player == null or cam == null:
        _fail("The same real Yuna controller and camera must be instantiated")
        return
    if player.get("art_study_treatment") != 1 or study.treatment != 1:
        _fail("Visual study doesn't start in graphic treatment")
        return
    var geometry: int = 0
    var blocked_light: int = 0
    for node: Node in study.get_children():
        if node is StaticBody2D:
            geometry += 1
            for child: Node in node.get_children():
                if child is LightOccluder2D:
                    blocked_light += 1
    if geometry != 2 or blocked_light != 1:
        _fail("Art treatments must share exactly two blockers and tall occluder")
        return
    var first_cam_zoom: Vector2 = cam.zoom
    var first_footprint: Vector2 = (player.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect().size
    study.call("set_treatment", 2)
    if player.get("art_study_treatment") != 2 or cam.zoom != first_cam_zoom:
        _fail("Soft treatment altered camera or didn't reach Yuna")
        return
    study.call("set_night", true)
    if not study.night:
        _fail("Day/night light control not working")
        return
    var after: Vector2 = (player.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect().size
    if after != first_footprint:
        _fail("Art study touched player collision shape")
        return
    var start: Vector2 = player.position
    Input.action_press("move_right")
    for i: int in range(12):
        await get_tree().physics_frame
    Input.action_release("move_right")
    if player.position.x <= start.x + 2.0:
        _fail("Player isn't moving with genuine Yuna controls")
        return
    if GameSession.current_level != "shelter":
        _fail("Visual study shouldn't change game level")
        return
    print("PASS: identical playable art study geometry, actor movement, shadow and day/night treatments")
    study.queue_free()
    get_tree().quit(0)


func _fail(message: String) -> void:
    Input.action_release("move_right")
    push_error("Visual study smoke failure: " + message)
    get_tree().quit(1)
