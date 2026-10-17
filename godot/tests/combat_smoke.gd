extends Node
## Real Godot physics/raycast smoke; two weapons, cover, reload, enemy AI and save.
## Run as a scene so GameSession Autoload is available.

func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    GameSession.current_level = "outdoors"
    GameSession.outdoor_position = Vector2(750, 320)
    GameSession.set_world_flag(&"world/cable_forest/survey_guard_01", false)
    GameSession.combat_state = {
        "selected": "pistol",
        "pistol": {"clip": 8, "reserve": 32},
        "rifle": {"clip": 4, "reserve": 16}
    }
    var outdoors: Node2D = (load("res://scenes/world/outdoors.tscn") as PackedScene).instantiate() as Node2D
    add_child(outdoors)
    var yuna: CharacterBody2D = outdoors.get_node("Yuna") as CharacterBody2D
    var weapon: Node2D = yuna.get_node("Weapons") as Node2D
    var guard: CharacterBody2D = outdoors.get_node_or_null("WorldStreamer/CableEdgeChunk/SurveyGuard") as CharacterBody2D
    var maintainer: CharacterBody2D = outdoors.get_node_or_null("WorldStreamer/AshFlatsChunk/NeutralMaintainer") as CharacterBody2D
    if guard == null or maintainer == null:
        _fail("Hostile and neutral machine need to be loaded")
        return
    guard.set_physics_process(false)
    maintainer.set_physics_process(false)
    await get_tree().physics_frame
    if not guard.call("has_line_of_sight", yuna):
        _fail("Guard cannot detect visible player on unobstructed path")
        return
    if maintainer.has_method("take_damage") or maintainer.is_in_group("robot_sensors"):
        _fail("Neutral worker must not behave as a hostile")
        return

    # Add actual physics collision as cover; raycast and enemy visibility must agree.
    var cover := StaticBody2D.new()
    cover.position = Vector2(820, 320)
    var cover_shape := CollisionShape2D.new()
    var rectangle := RectangleShape2D.new()
    rectangle.size = Vector2(24, 90)
    cover_shape.shape = rectangle
    cover.add_child(cover_shape)
    outdoors.add_child(cover)
    await get_tree().physics_frame
    if guard.call("has_line_of_sight", yuna):
        _fail("Line-of-sight passed through solid cover")
        return
    var durability: int = int(guard.get("durability"))
    if not weapon.call("shoot_at", guard.global_position):
        _fail("Pistol couldn't shoot")
        return
    if int(guard.get("durability")) != durability:
        _fail("Projectile damaged guard through cover")
        return
    cover.collision_layer = 0
    await get_tree().physics_frame

    if not guard.call("has_line_of_sight", yuna):
        _fail("Removing cover didn't restore visibility")
        return
    if weapon.call("shoot_at", guard.global_position):
        _fail("Shot bypassed weapon fire interval")
        return
    await _physics_frames(24)
    if not weapon.call("shoot_at", guard.global_position):
        _fail("Pistol cannot hit exposed guard")
        return
    if int(guard.get("durability")) >= durability:
        _fail("A clear pistol shot didn't reduce robot durability")
        return
    if not weapon.call("switch_weapon", &"rifle"):
        _fail("Rifle switch failed")
        return
    await _physics_frames(42)
    var before_rifle: int = int(guard.get("durability"))
    if not weapon.call("shoot_at", guard.global_position):
        _fail("Rifle wouldn't fire")
        return
    if int(guard.get("durability")) >= before_rifle:
        _fail("Rifle didn't affect hostile durability")
        return

    var rifle_ammo: Dictionary = GameSession.combat_state["rifle"]
    if int(rifle_ammo["clip"]) != 3:
        _fail("Rifle magazine wasn't consumed")
        return
    rifle_ammo["clip"] = 0
    GameSession.combat_state["rifle"] = rifle_ammo
    if not weapon.call("start_reload"):
        _fail("Rifle reload could not begin")
        return
    await _physics_frames(115)
    rifle_ammo = GameSession.combat_state["rifle"]
    if int(rifle_ammo["clip"]) != 4 or int(rifle_ammo["reserve"]) != 12:
        _fail("Reload failed to transfer exact rounds: " + str(rifle_ammo))
        return
    var saved: Dictionary = GameSession.snapshot()
    GameSession.combat_state["rifle"] = {"clip": 1, "reserve": 0}
    if not GameSession.restore_snapshot(saved):
        _fail("Combat state failed to restore")
        return
    if int((GameSession.combat_state["rifle"] as Dictionary)["reserve"]) != 12:
        _fail("Saved ammo was not restored")
        return
    var invalid: Dictionary = saved.duplicate(true)
    (invalid["combat_state"] as Dictionary)["rifle"] = {"clip": 1.5, "reserve": 3}
    if GameSession.restore_snapshot(invalid):
        _fail("Fractional ammunition was accepted")
        return

    # Stressful contact temporarily affects movement, without a player HP bar.
    guard.set_physics_process(true)
    yuna.position = guard.global_position + Vector2(23, 0)
    await _physics_frames(7)
    if yuna.hits_taken < 1 or not yuna.call("is_staggered"):
        _fail("Hostile contact didn't produce a bounded stagger")
        return
    # Escape far enough to break detection; no rank/quest gate.
    yuna.position = Vector2(60, 60)
    await _physics_frames(6)
    if guard.get("state") == &"pursue":
        _fail("Robot did not lose pursuit after player retreated")
        return

    print("PASS: cover blocks sight/bullets, pistol/rifle, cooldown, reload, saved ammo, neutral machine and avoidable hostile pressure")
    outdoors.queue_free()
    get_tree().quit(0)


func _physics_frames(count: int) -> void:
    for i: int in range(count):
        await get_tree().physics_frame


func _fail(message: String) -> void:
    push_error("Combat smoke failure: " + message)
    get_tree().quit(1)
