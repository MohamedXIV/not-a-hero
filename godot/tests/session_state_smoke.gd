extends SceneTree
## Run with: godot --headless --path godot --script res://tests/session_state_smoke.gd
## Pure state checks; does not touch local player save files.


func _initialize() -> void:
    call_deferred("_check")


func _check() -> void:
    var session_script: GDScript = load("res://scripts/core/game_session.gd") as GDScript
    var session: Node = session_script.new() as Node
    session.call("set_world_flag", &"world/ash_flats/relay_01", true)
    session.set("current_level", "outdoors")
    session.set("outdoor_position", Vector2(1470.0, 290.0))
    var bag: InventoryState = session.get("bag") as InventoryState
    _assert_ok(bag.try_receive({"scrap": 3, "wire": 1}), "inventory accepts valid loot")
    var storage: InventoryState = session.get("storage") as InventoryState
    _assert_ok(storage.try_receive({"capacitor": 6, "alloy": 4}), "storage holds supplies")
    var vitals: YunaCondition = session.get("condition") as YunaCondition
    vitals.receive_impact(&"leg")
    vitals.apply_pressure(13.0)
    session.set("home_supplies", {"meals": 3, "water": 5})
    var decorated: ShelterDecorState = session.get("decor") as ShelterDecorState
    _assert_ok(decorated.place("rug", Vector2(448, 384)), "placed starter rug")
    var produce: HomeProduction = session.get("production") as HomeProduction
    produce.advance(480.0)
    _assert_ok(produce.ready_water == 2 and produce.ready_culture == 1, "time produces bounded supplies")
    var journal: NotebookState = session.get("notebook") as NotebookState
    _assert_ok(journal.discover("cable_scarred_junction"), "physically witnessed clue recorded")
    _assert_ok(journal.pin("cable_scarred_junction"), "player may pin a known note")
    var clock: MachineEcology = session.get("ecology") as MachineEcology
    clock.advance(725.0)
    _assert_ok(clock.epoch("dead_foundry") == 2, "whole-world machine time advances")
    var snapshot: Dictionary = session.call("snapshot")
    _assert_ok(snapshot.get("world_flags", {}).get("world/ash_flats/relay_01", false), "switch included in snapshot")

    session.call("set_world_flag", &"world/ash_flats/relay_01", false)
    session.set("current_level", "shelter")
    bag.try_spend(&"scrap", 3)
    session.set("home_supplies", {"meals": 0, "water": 0})
    storage.try_spend(&"alloy", 4)
    decorated.remove_at(0)
    produce.take_water()
    clock.advance(360.0)
    journal = NotebookState.new()
    session.set("notebook", journal)
    vitals.rest_at_home()
    _assert_ok(session.call("restore_snapshot", snapshot), "valid snapshot accepted")
    _assert_ok(session.call("get_world_flag", &"world/ash_flats/relay_01"), "world switch restored")
    _assert_ok(session.get("current_level") == "outdoors", "current level restored")
    _assert_ok(int((session.get("home_supplies") as Dictionary)["meals"]) == 3, "shelter food supplies restored")
    _assert_ok((session.get("bag") as InventoryState).quantity(&"scrap") == 3, "inventory restored")
    _assert_ok((session.get("storage") as InventoryState).quantity(&"alloy") == 4, "storage restored")
    _assert_ok((session.get("decor") as ShelterDecorState).count_kind("rug") == 1, "furniture restored")
    _assert_ok((session.get("production") as HomeProduction).ready_water == 2, "shelter production restored")
    _assert_ok((session.get("ecology") as MachineEcology).epoch("dead_foundry") == 2, "offscreen ecology clock restored")
    _assert_ok((session.get("notebook") as NotebookState).knows("cable_scarred_junction"), "observed clue restored")
    _assert_ok((session.get("notebook") as NotebookState).pinned == "cable_scarred_junction", "pinned note restored")
    _assert_ok(int((session.get("condition") as YunaCondition).injuries["leg"]) == 1, "localized injury restored")
    _assert_ok(session.get("outdoor_position") == Vector2(1470.0, 290.0), "global player coordinate restored")

    var invalid: Dictionary = snapshot.duplicate(true)
    invalid["world_flags"] = {"world/ash_flats/relay_01": "invalid string"}
    var before: Dictionary = session.call("snapshot")
    _assert_ok(not session.call("restore_snapshot", invalid), "invalid switch rejected")
    _assert_ok(session.call("snapshot") == before, "invalid save did not partially mutate state")

    invalid = snapshot.duplicate(true)
    invalid["storage"] = {"alloy": 2.4}
    _assert_ok(not session.call("restore_snapshot", invalid), "invalid storage rejected")
    _assert_ok(session.call("snapshot") == before, "invalid storage never partially mutates")
    invalid = snapshot.duplicate(true)
    invalid["condition"] = snapshot["condition"].duplicate(true)
    invalid["condition"]["composure"] = -3.0
    _assert_ok(not session.call("restore_snapshot", invalid), "invalid composure rejected")
    _assert_ok(session.call("snapshot") == before, "invalid condition never partially mutates")
    invalid = snapshot.duplicate(true)
    invalid["home_supplies"] = {"meals": 2.5, "water": 3}
    _assert_ok(not session.call("restore_snapshot", invalid), "fractional food rejected")
    _assert_ok(session.call("snapshot") == before, "bad supplies must not mutate game")
    invalid = snapshot.duplicate(true)
    invalid["shelter_decor"][0]["x"] = 160.0
    _assert_ok(not session.call("restore_snapshot", invalid), "blocked decor placement rejected")
    _assert_ok(session.call("snapshot") == before, "invalid furniture must not change saved state")
    invalid = snapshot.duplicate(true)
    invalid["home_production"]["ready_culture"] = 900
    _assert_ok(not session.call("restore_snapshot", invalid), "uncapped production save rejected")
    _assert_ok(session.call("snapshot") == before, "invalid production never partially mutates game")
    invalid = snapshot.duplicate(true)
    invalid["notebook"]["observed"].append("unknown_invisible_secret")
    _assert_ok(not session.call("restore_snapshot", invalid), "unseen/unknown note rejected")
    _assert_ok(session.call("snapshot") == before, "invalid notebook cannot partially mutate game")
    invalid = snapshot.duplicate(true)
    invalid["ecology"]["claimed"]["dead_foundry"] = 999
    _assert_ok(not session.call("restore_snapshot", invalid), "future machine shift claim rejected")
    _assert_ok(session.call("snapshot") == before, "invalid ecology cannot mutate running save")
    invalid = snapshot.duplicate(true)
    invalid["version"] = 999
    _assert_ok(not session.call("restore_snapshot", invalid), "incompatible version rejected")
    # Use a dedicated temporary path: test must never replace an actual player's save.
    var path: String = "user://naah_p0_session_test.json"
    session.call("set_world_flag", &"world/ash_flats/relay_01", true)
    _assert_ok(session.call("save_to_disk", path), "real FileAccess save succeeds")
    session.call("set_world_flag", &"world/ash_flats/relay_01", false)
    _assert_ok(session.call("load_from_disk", path), "real FileAccess load succeeds")
    _assert_ok(session.call("get_world_flag", &"world/ash_flats/relay_01"), "real disk save restored switch")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    print("PASS: versioned snapshot, real file I/O and persistent world flags")
    session.free()
    quit(0)


func _assert_ok(condition: bool, label: String) -> void:
    if not condition:
        push_error("FAIL: " + label)
        quit(1)
        # The rest of this check should not be considered passing.
        assert(condition, label)
