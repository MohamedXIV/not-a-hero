extends Node
## Real starter shelter StorageChest interaction + all-or-nothing inventory transfers.

func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    GameSession.bag = InventoryState.new()
    GameSession.storage = InventoryState.new(120)
    if not GameSession.bag.try_receive({"scrap": 4, "capacitor": 2}):
        _fail("Could not prepare initial bag")
        return
    var scene: PackedScene = load("res://scenes/interiors/starter_shelter.tscn") as PackedScene
    var shelter: Node2D = scene.instantiate() as Node2D
    add_child(shelter)
    var chest: Node2D = shelter.get_node_or_null("StorageChest") as Node2D
    var yuna: CharacterBody2D = shelter.get_node("Yuna") as CharacterBody2D
    if chest == null:
        _fail("StorageChest missing from shelter")
        return
    yuna.position = chest.position + Vector2(0, 56)
    if not str(shelter.call("get_interaction_hint")).contains("Store bag"):
        _fail("No discoverable storage interaction prompt")
        return
    if not chest.call("interact", false):
        _fail("Store action failed")
        return
    if not GameSession.bag.snapshot().is_empty() or GameSession.storage.quantity(&"scrap") != 4:
        _fail("Deposit did not move real items to storage")
        return

    var saved: Dictionary = GameSession.snapshot()
    GameSession.storage = InventoryState.new(120)
    if not GameSession.restore_snapshot(saved) or GameSession.storage.quantity(&"capacitor") != 2:
        _fail("Stored supplies did not survive snapshot roundtrip")
        return
    if not chest.call("interact", true):
        _fail("Withdraw action failed")
        return
    if GameSession.bag.quantity(&"scrap") != 4 or GameSession.storage.total_units() != 0:
        _fail("Withdraw did not return items")
        return

    GameSession.storage.try_receive({"alloy": 29})
    var bag_before: Dictionary = GameSession.bag.snapshot()
    var store_before: Dictionary = GameSession.storage.snapshot()
    if chest.call("interact", true):
        _fail("Overflowing bag accepted an invalid transfer")
        return
    if bag_before != GameSession.bag.snapshot() or store_before != GameSession.storage.snapshot():
        _fail("Rejected withdraw modified inventory")
        return
    print("PASS: starter shelter chest deposit, withdraw, storage persistence and atomic overflow rejection")
    shelter.queue_free()
    get_tree().quit(0)


func _fail(message: String) -> void:
    push_error("Storage smoke failure: " + message)
    get_tree().quit(1)
