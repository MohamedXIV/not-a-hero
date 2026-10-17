extends Node
## Real Little Nest proximity interactions: productive home day, finite collection,
## fiber-based care, ritual cooldown, focus-safe crafting and save/load.

func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    GameSession.current_level = "shelter"
    GameSession.production = HomeProduction.new()
    GameSession.home_supplies = {"meals": 3, "water": 5}
    GameSession.bag = InventoryState.new()
    GameSession.condition = YunaCondition.new()
    var scene: PackedScene = load("res://scenes/interiors/starter_shelter.tscn") as PackedScene
    var shelter: Node2D = scene.instantiate() as Node2D
    add_child(shelter)
    var yuna: CharacterBody2D = shelter.get_node("Yuna") as CharacterBody2D

    # Sleep is a voluntary safe home action; time advances life support.
    GameSession.sleep_at_home()
    if GameSession.production.ready_water != 1 or GameSession.production.ready_culture != 0:
        _fail("Rest failed to advance condenser and culture clock")
        return
    GameSession.sleep_at_home()
    if GameSession.production.ready_culture != 1:
        _fail("Cultivation never matured after enough home time")
        return
    yuna.position = shelter.CONDENSER_POINT
    if not str(shelter.call("get_interaction_hint")).contains("condensed water"):
        _fail("Condenser is not discoverable")
        return
    shelter.call("_interact_nearby")
    if int(GameSession.home_supplies["water"]) != 6 or GameSession.production.ready_water != 1:
        _fail("Water harvest didn't consume exactly one ready portion")
        return
    yuna.position = shelter.CULTURE_POINT
    if not str(shelter.call("get_interaction_hint")).contains("Harvest"):
        _fail("Culture harvesting hint is missing")
        return
    shelter.call("_interact_nearby")
    if int(GameSession.home_supplies["meals"]) != 4 or GameSession.bag.quantity(&"fiber") != 1:
        _fail("Culture harvest didn't produce exactly one meal and fiber")
        return
    var previous: Dictionary = GameSession.snapshot()
    shelter.call("_interact_nearby")
    if GameSession.snapshot() != previous:
        _fail("Picking empty culture tray duplicated supplies")
        return
    GameSession.production.advance(480.0)
    shelter.call("_interact_nearby")
    if GameSession.bag.quantity(&"fiber") != 2:
        _fail("Second grow cycle did not yield materials for dressing")
        return
    var bench: Node2D = shelter.get_node("Workbench") as Node2D
    GameSession.condition.composure = 2.0
    if bench.call("craft_field_dressing") or GameSession.bag.quantity(&"fiber") != 2:
        _fail("Overwhelmed Yuna crafted delicate dressing anyway")
        return
    GameSession.condition.composure = 50.0
    if not bench.call("craft_field_dressing"):
        _fail("Workbench failed to craft a renewable dressing")
        return
    if GameSession.bag.quantity(&"dressing") != 1 or GameSession.bag.quantity(&"fiber") != 0:
        _fail("Field dressing recipe incorrect or duplicated")
        return
    if bench.call("craft_field_dressing"):
        _fail("Repeated craft without fiber duplicated dressings")
        return

    yuna.position = shelter.RADIO_POINT
    GameSession.condition.composure = 30.0
    GameSession.condition.fatigue = 55.0
    shelter.call("_interact_nearby")
    var calm: float = GameSession.condition.composure
    if calm <= 30.0 or GameSession.production.can_unwind():
        _fail("Real radio failed to offer bounded calm + cooldown")
        return
    shelter.call("_interact_nearby")
    if GameSession.condition.composure != calm:
        _fail("Radio could be spammed for composure")
        return

    # With a full bag, culture harvest should leave food and plant unchanged.
    GameSession.bag = InventoryState.new()
    GameSession.bag.try_receive({"scrap": 24})
    GameSession.production.advance(480.0)
    var food: int = int(GameSession.home_supplies["meals"])
    var ready: int = GameSession.production.ready_culture
    if GameSession.harvest_culture() or ready != GameSession.production.ready_culture:
        _fail("Full bag harvested fiber / mutated culture progress")
        return
    if int(GameSession.home_supplies["meals"]) != food:
        _fail("Full bag harvest added food without fiber")
        return

    var saved: Dictionary = GameSession.snapshot()
    GameSession.production = HomeProduction.new()
    if not GameSession.restore_snapshot(saved) or GameSession.snapshot() != saved:
        _fail("Home renewal state did not survive snapshot roundtrip")
        return
    if not GameSession.save_to_disk("user://nah_p2_home_life_test.json"):
        _fail("Home life FileAccess save failed")
        return
    GameSession.production = HomeProduction.new()
    if not GameSession.load_from_disk("user://nah_p2_home_life_test.json"):
        _fail("Home life FileAccess reload failed")
        return
    if GameSession.snapshot() != saved:
        _fail("Home production / food / supplies not restored from disk")
        return
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://nah_p2_home_life_test.json"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSession.SAVE_PATH))
    print("PASS: quiet home day, water/culture harvest, dressings, radio, anti-dupe and real disk persistence")
    shelter.queue_free()
    get_tree().quit(0)


func _fail(message: String) -> void:
    push_error("Home life smoke: " + message)
    get_tree().quit(1)
