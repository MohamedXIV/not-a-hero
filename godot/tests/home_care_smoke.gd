extends Node
## Actual shelter interaction: eating, drinking and portable first aid are finite,
## persisted, and cannot consume items on rejected actions.

func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    GameSession.current_level = "shelter"
    GameSession.condition = YunaCondition.new()
    GameSession.bag = InventoryState.new()
    GameSession.bag.try_receive({"dressing": 2})
    GameSession.home_supplies = {"meals": 2, "water": 2}
    GameSession.condition.nourishment = 22.0
    GameSession.condition.hydration = 17.0
    var scene: PackedScene = load("res://scenes/interiors/starter_shelter.tscn") as PackedScene
    var shelter: Node2D = scene.instantiate() as Node2D
    add_child(shelter)
    var yuna: CharacterBody2D = shelter.get_node("Yuna") as CharacterBody2D
    yuna.position = Vector2(213, 360)
    if not str(shelter.call("get_interaction_hint")).contains("meal"):
        _fail("Cooking station has no prompt")
        return
    shelter.call("_interact_nearby")
    if GameSession.condition.nourishment <= 22.0 or int(GameSession.home_supplies["meals"]) != 1:
        _fail("Meal didn't restore nourishment or consumed incorrect supplies")
        return
    yuna.position = Vector2(290, 165)
    if not str(shelter.call("get_interaction_hint")).contains("water"):
        _fail("Water station has no prompt")
        return
    shelter.call("_interact_nearby")
    if GameSession.condition.hydration <= 17.0 or int(GameSession.home_supplies["water"]) != 1:
        _fail("Drinking did not hydrate or consumed incorrect supplies")
        return
    GameSession.condition.receive_impact(&"leg")
    var unbandaged_movement: float = GameSession.condition.movement_modifier()
    if not GameSession.use_field_dressing():
        _fail("Starting field dressing could not stabilize leg")
        return
    if not GameSession.condition.bandaged["leg"] or GameSession.bag.quantity(&"dressing") != 1:
        _fail("Field first aid did not consume exactly one dressing")
        return
    if GameSession.condition.movement_modifier() <= unbandaged_movement:
        _fail("Stabilized leg did not alleviate movement penalty")
        return
    if GameSession.use_field_dressing() or GameSession.bag.quantity(&"dressing") != 1:
        _fail("Already bandaged injury spent a second dressing")
        return
    var snapshot: Dictionary = GameSession.snapshot()
    GameSession.condition = YunaCondition.new()
    GameSession.home_supplies = {"meals": 0, "water": 0}
    if not GameSession.restore_snapshot(snapshot):
        _fail("Valid food/first aid save refused")
        return
    if not GameSession.condition.bandaged["leg"] or int(GameSession.home_supplies["water"]) != 1:
        _fail("First aid and water didn't survive save restore")
        return
    var before: Dictionary = GameSession.snapshot()
    var tampered: Dictionary = before.duplicate(true)
    tampered["condition"]["bandaged"]["arm"] = true
    if GameSession.restore_snapshot(tampered) or GameSession.snapshot() != before:
        _fail("Invalid dressing without injury improperly accepted or modified game")
        return
    DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSession.SAVE_PATH))
    print("PASS: real shelter meals/water, portable first aid, atomic supply use and persistent care")
    shelter.queue_free()
    get_tree().quit(0)


func _fail(reason: String) -> void:
    push_error("Home care smoke: " + reason)
    get_tree().quit(1)
