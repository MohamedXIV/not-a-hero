extends Node
## Scene level interaction: craft deferral when overwhelmed, then bed rest recovery.

func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    GameSession.current_level = "shelter"
    GameSession.bag = InventoryState.new()
    GameSession.condition = YunaCondition.new()
    GameSession.condition.composure = 3.0
    GameSession.condition.fatigue = 89.0
    GameSession.condition.receive_impact(&"arm")
    GameSession.bag.try_receive({"scrap": 3, "wire": 1})
    var shelter: Node2D = (load("res://scenes/interiors/starter_shelter.tscn") as PackedScene).instantiate() as Node2D
    add_child(shelter)
    var workbench: Node2D = shelter.get_node("Workbench") as Node2D
    if workbench.call("interact") or GameSession.bag.quantity(&"scrap") != 3:
        _fail("Distressed crafting must fail without consuming materials")
        return
    var yuna: CharacterBody2D = shelter.get_node("Yuna") as CharacterBody2D
    yuna.position = Vector2(235, 278)
    if not str(shelter.call("get_interaction_hint")).contains("Rest"):
        _fail("Yuna cannot find the bed interaction")
        return
    var clock: float = GameSession.day_minutes
    Input.action_press("interact")
    await get_tree().process_frame
    Input.action_release("interact")
    if not GameSession.condition.can_focus():
        _fail("Actual bed interaction didn't restore focus")
        return
    if GameSession.day_minutes == clock:
        _fail("Sleeping didn't advance in-world time")
        return
    if not workbench.call("interact") or GameSession.bag.quantity(&"relay_fuse") != 1:
        _fail("Yuna could not resume complex work after resting")
        return
    if not (GameSession.condition.injury_description().contains("Uninjured")):
        _fail("One minor arm injury didn't recover after bed rest")
        return
    DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSession.SAVE_PATH))
    print("PASS: actual bed rest, focus gate, workbench return and localized healing")
    shelter.queue_free()
    get_tree().quit(0)


func _fail(message: String) -> void:
    Input.action_release("interact")
    push_error("Yuna condition scene smoke: " + message)
    get_tree().quit(1)
