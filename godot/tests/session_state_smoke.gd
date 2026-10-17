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
    var snapshot: Dictionary = session.call("snapshot")
    _assert_ok(snapshot.get("world_flags", {}).get("world/ash_flats/relay_01", false), "switch included in snapshot")

    session.call("set_world_flag", &"world/ash_flats/relay_01", false)
    session.set("current_level", "shelter")
    _assert_ok(session.call("restore_snapshot", snapshot), "valid snapshot accepted")
    _assert_ok(session.call("get_world_flag", &"world/ash_flats/relay_01"), "world switch restored")
    _assert_ok(session.get("current_level") == "outdoors", "current level restored")
    _assert_ok(session.get("outdoor_position") == Vector2(1470.0, 290.0), "global player coordinate restored")

    var invalid: Dictionary = snapshot.duplicate(true)
    invalid["world_flags"] = {"world/ash_flats/relay_01": "invalid string"}
    var before: Dictionary = session.call("snapshot")
    _assert_ok(not session.call("restore_snapshot", invalid), "invalid switch rejected")
    _assert_ok(session.call("snapshot") == before, "invalid save did not partially mutate state")

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
