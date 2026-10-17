extends SceneTree
## Deterministic placement validation: room boundaries, furniture, hatch and JSON.

func _initialize() -> void:
    call_deferred("_check")


func _check() -> void:
    var home := ShelterDecorState.new()
    assert(not home.place("unknown", Vector2(448, 384)), "Unknown decor type forbidden")
    assert(not home.place("rug", Vector2(160, 200)), "No rug can overlap sleeping bed")
    assert(not home.place("lantern", Vector2(330, 442)), "Hatch must remain unblocked")
    assert(not home.place("lantern", Vector2(498, 270)), "Workbench must remain reachable")
    assert(home.place("rug", Vector2(448, 384)), "Valid central rug fits")
    assert(home.place("lantern", Vector2(544, 384)), "Valid lantern fits")
    assert(not home.place("rug", Vector2(448, 384)), "Placed objects cannot overlap")
    assert(home.count_kind("rug") == 1 and home.count_kind("lantern") == 1, "Items unique")
    var source: Array[Dictionary] = home.items()
    var restored := ShelterDecorState.new()
    assert(restored.restore_snapshot(JSON.parse_string(JSON.stringify(source))), "JSON roundtrip placements")
    assert(restored.items() == source, "Saved coordinates reproduced byte-equivalent")
    var invalid: Array = source.duplicate(true)
    invalid[0]["kind"] = "unknown"
    assert(not restored.restore_snapshot(invalid), "Unknown furnishings rejected")
    assert(restored.items() == source, "Invalid restore is atomic")
    invalid = source.duplicate(true)
    invalid[1]["x"] = 160.0
    invalid[1]["y"] = 200.0
    assert(not restored.restore_snapshot(invalid), "Blocking bed rejected in save")
    assert(restored.items() == source, "Blocked restore cannot overwrite home")
    invalid = source.duplicate(true)
    invalid[0]["x"] = 447.2
    assert(not restored.restore_snapshot(invalid), "Non-grid position rejected")
    assert(restored.at_point(Vector2(544, 384)) == 1, "Lantern is selectable")
    assert(restored.remove_at(1) == "lantern", "Pick-up resolves real decor")
    assert(restored.count_kind("lantern") == 0, "Removed piece disappears")
    print("PASS: authored decor grid, collision/hatch validation, retrieval and atomic save restore")
    quit(0)
