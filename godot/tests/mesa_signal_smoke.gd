extends SceneTree
## P4e: two actual observations, optional reversible machine rerouting,
## and strict atomic persisted chronology without a forced story revelation.


func _initialize() -> void:
    call_deferred("_check")


func _opened_mesa() -> MesaState:
    var mesa := MesaState.new()
    assert(mesa.examine())
    for i: int in range(MesaState.MANUAL_STAGES):
        assert(mesa.turn_handwheel())
    assert(mesa.make_first_sector_safe())
    assert(mesa.work_power() and mesa.work_power())
    return mesa


func _check() -> void:
    var mesa := _opened_mesa()
    assert(not mesa.inspect_service_signal(), "Sealed rear gallery cannot be read")
    assert(not mesa.toggle_service_signal(), "No invisible reroute")
    assert(mesa.work_flow() and mesa.work_flow(), "Always available without rare loot")
    assert(mesa.inspect_service_signal(), "Player can read working service carrier")
    assert(not mesa.inspect_service_signal(), "One first observation")
    assert(not mesa.service_signal_diverted, "Observation does not force diversion")
    assert(mesa.toggle_service_signal() and mesa.service_signal_diverted, "Can redirect without fighting")
    assert(mesa.toggle_service_signal() and not mesa.service_signal_diverted, "Can change mind")
    assert(mesa.toggle_service_signal() and mesa.service_signal_diverted, "Choice remains functional")
    assert(not mesa.court_restored() and not mesa.first_night_spent, "No fake garden or story progress")
    var original: Dictionary = mesa.snapshot()
    var copy := MesaState.new()
    assert(copy.restore_snapshot(JSON.parse_string(JSON.stringify(original))), "v16 signal JSON")
    assert(copy.snapshot() == original, "Exact persistence")
    var invalid: Dictionary = original.duplicate(true)
    invalid["flow_method"] = ""
    assert(not copy.restore_snapshot(invalid) and copy.snapshot() == original, "Signal cannot exist without coolant")
    invalid = original.duplicate(true)
    invalid["service_signal_inspected"] = false
    assert(not copy.restore_snapshot(invalid) and copy.snapshot() == original, "Diversion requires inspection")
    for field: String in ["service_signal_inspected", "service_signal_diverted"]:
        invalid = original.duplicate(true)
        invalid[field] = 1
        assert(not copy.restore_snapshot(invalid) and copy.snapshot() == original, "Strict flag type")
        invalid = original.duplicate(true)
        invalid.erase(field)
        assert(not copy.restore_snapshot(invalid) and copy.snapshot() == original, "Missing field rejected")

    var notes := NotebookState.new()
    assert(notes.discover("mesa_return_carrier"), "Independent inside observation")
    assert(notes.related_inferences("mesa_return_carrier").is_empty(), "Do not reveal unseen outside machine")
    assert(notes.mesa_leads().is_empty(), "Optional inference never gates entrance")
    assert(notes.discover("mesa_service_tracks"), "Later outside observation")
    assert(notes.related_inferences("mesa_service_tracks").size() == 1, "Witnessed evidence yields cautious explanation")
    assert(notes.inference().contains("who sent it"), "Mystery stays open")
    assert(not notes.discover("mesa_return_carrier"), "Cannot farm clue")
    var reversed := NotebookState.new()
    assert(reversed.discover("mesa_service_tracks") and reversed.discover("mesa_return_carrier"), "Reverse discovery order")
    assert(reversed.inference() == notes.inference(), "Authoring does not depend on finding a required first clue")
    var journal_copy := NotebookState.new()
    assert(journal_copy.restore_snapshot(JSON.parse_string(JSON.stringify(notes.snapshot()))), "Notes survive JSON")
    assert(journal_copy.inference() == notes.inference(), "Cautious connection survives save")
    print("PASS: reversible physical service route, independent observed machine clues and atomic v16 chronology")
    quit(0)
