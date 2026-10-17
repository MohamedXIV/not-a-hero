extends SceneTree
## Independent clue ordering, authored evidence gating, no quest log.

func _initialize() -> void:
    call_deferred("_check")


func _check() -> void:
    var notes := NotebookState.new()
    assert(notes.observed_ids().is_empty() and notes.inference().is_empty(), "Start with no hidden clues")
    assert(not notes.pin("ash_warm_conduit"), "Cannot pin facts before seeing them")
    assert(not notes.discover("not_authored"), "Unknown world fact cannot be discovered")
    assert(notes.discover("cable_scarred_junction"), "Cable observation found first")
    assert(notes.inference().is_empty(), "Second clue must not leak early")
    assert(not notes.discover("cable_scarred_junction"), "Re-examination doesn't duplicate")
    assert(notes.pin("cable_scarred_junction"), "Pin a witnessed note")
    assert(notes.discover("ash_warm_conduit"), "Ash observation found second")
    assert(not notes.inference().is_empty(), "Two known clues yield a tentative inference")
    var reversed := NotebookState.new()
    assert(reversed.discover("ash_warm_conduit") and reversed.discover("cable_scarred_junction"), "Reverse order valid")
    assert(reversed.inference() == notes.inference(), "Order doesn't gate deduction")
    var saved: Dictionary = notes.snapshot()
    var loaded := NotebookState.new()
    assert(loaded.restore_snapshot(JSON.parse_string(JSON.stringify(saved))), "Observed notes survive JSON")
    assert(loaded.snapshot() == saved, "Notes and pinned state roundtrip")
    var before: Dictionary = loaded.snapshot()
    var invalid: Dictionary = before.duplicate(true)
    invalid["observed"].append("secret_mesa_code")
    assert(not loaded.restore_snapshot(invalid) and loaded.snapshot() == before, "Unknown secrets rejected atomically")
    invalid = before.duplicate(true)
    invalid["observed"].append("ash_warm_conduit")
    assert(not loaded.restore_snapshot(invalid) and loaded.snapshot() == before, "Repeated discovered ID rejected")
    invalid = before.duplicate(true)
    invalid["pinned"] = "secret_mesa_code"
    assert(not loaded.restore_snapshot(invalid) and loaded.snapshot() == before, "Unseen pin rejected")
    assert(notes.pin("cable_scarred_junction") and notes.pinned.is_empty(), "Pin can be removed")
    print("PASS: discovery notes are witnessed, order independent, non-duplicated and validated")
    quit(0)
