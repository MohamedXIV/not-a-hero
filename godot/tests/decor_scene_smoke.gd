extends Node
## Actual Little Nest furniture scene: inventory-backed rug and light fixture,
## change location, pickup, no dupes, durable furniture and item snapshots.

func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    GameSession.current_level = "shelter"
    GameSession.decor = ShelterDecorState.new()
    GameSession.bag = InventoryState.new()
    GameSession.bag.try_receive({"rug": 1, "lantern": 1})
    var scene: PackedScene = load("res://scenes/interiors/starter_shelter.tscn") as PackedScene
    var shelter: Node2D = scene.instantiate() as Node2D
    add_child(shelter)
    var decorator: Node2D = shelter.get_node("ShelterDecorator") as Node2D
    if decorator == null or not str(decorator.call("hint")).contains("G"):
        _fail("Decor mode not discoverable in a real shelter")
        return
    if decorator.call("place_at", "rug", Vector2(160, 200)):
        _fail("Could place rug over bed")
        return
    if GameSession.bag.quantity(&"rug") != 1:
        _fail("Rejected placement lost bag item")
        return
    if not decorator.call("place_at", "rug", Vector2(448, 384)):
        _fail("Could not place owned rug")
        return
    if not decorator.call("place_at", "lantern", Vector2(544, 384)):
        _fail("Could not place owned lantern")
        return
    if GameSession.bag.quantity(&"rug") != 0 or GameSession.bag.quantity(&"lantern") != 0:
        _fail("Placed furniture wasn't consumed exactly once")
        return
    var light_count: int = 0
    var collider_count: int = 0
    for child: Node in decorator.get_children():
        if child is PointLight2D:
            light_count += 1
        if child is StaticBody2D:
            collider_count += 1
    if light_count != 1 or collider_count != 1:
        _fail("Lantern is missing actual light or solid foot collider")
        return
    var saved: Dictionary = GameSession.snapshot()
    var fallback := ShelterDecorState.new()
    GameSession.decor = fallback
    if not GameSession.restore_snapshot(saved) or GameSession.decor.count_kind("lantern") != 1:
        _fail("Decorated home didn't survive a snapshot")
        return
    if not decorator.call("pickup_at", Vector2(544, 384)):
        _fail("Couldn't reclaim lamp to inventory")
        return
    if GameSession.bag.quantity(&"lantern") != 1 or GameSession.decor.count_kind("lantern") != 0:
        _fail("Pickup didn't reverse placement")
        return
    if not decorator.call("place_at", "lantern", Vector2(528, 424)):
        _fail("Couldn't place reclaimed lamp elsewhere")
        return
    if GameSession.decor.at_point(Vector2(528, 424)) < 0:
        _fail("New lantern position not persistent")
        return
    if not GameSession.save_to_disk("user://nah_p2_decor_test.json"):
        _fail("Decorated room FileAccess save failed")
        return
    var before: Dictionary = GameSession.snapshot()
    GameSession.decor = ShelterDecorState.new()
    if not GameSession.load_from_disk("user://nah_p2_decor_test.json"):
        _fail("Decorated room FileAccess reload failed")
        return
    if GameSession.snapshot() != before:
        _fail("Disk reload differs from saved room state")
        return
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://nah_p2_decor_test.json"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSession.SAVE_PATH))
    print("PASS: real furniture placement, light/collision, pickup/reposition and persistent decorated home")
    shelter.queue_free()
    get_tree().quit(0)


func _fail(reason: String) -> void:
    push_error("Decor scene smoke: " + reason)
    get_tree().quit(1)
