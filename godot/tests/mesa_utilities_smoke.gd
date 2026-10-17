extends SceneTree
## P4b: every utility has material-free counterplay, and rewards cannot
## be obtained without isolating the live sector and repairing in order.

func _initialize() -> void:
    call_deferred("_check")


func _check() -> void:
    var mesa := MesaState.new()
    var bag := InventoryState.new()
    assert(not mesa.work_power() and not mesa.work_flow(), "Cannot repair an undiscovered, live facility")
    assert(not mesa.replace_power_coupler(bag), "Cannot waste a part before safety is established")
    mesa.examine()
    for stage: int in range(3):
        assert(mesa.turn_handwheel(), "Entrance opens without any item")
    assert(not mesa.work_power(), "Opening the entrance does not make live bus safe")
    assert(mesa.make_first_sector_safe(), "Player can isolate a first room")
    assert(not mesa.work_flow(), "Flow requires power")
    assert(mesa.work_power() and mesa.power_progress == 1, "First manual power step recorded")
    var midway: Dictionary = mesa.snapshot()
    var resumed := MesaState.new()
    assert(resumed.restore_snapshot(JSON.parse_string(JSON.stringify(midway))), "Half-completed electrical work saved")
    assert(resumed.work_power() and resumed.power_online(), "Second manual step restores power")
    assert(resumed.power_method == "manual", "Provenance tracks manual repair")
    assert(not resumed.work_power(), "No infinite repair rewards")
    assert(resumed.work_flow() and resumed.flow_progress == 1, "First manual purge advances")
    assert(resumed.work_flow() and resumed.flow_online(), "Second purge unlocks gallery")
    assert(resumed.flow_method == "manual", "Provenance tracks manual coolant repair")
    assert(not resumed.work_flow(), "Already functioning loop can't be farmed")
    var manual: Dictionary = resumed.snapshot()
    var loaded := MesaState.new()
    assert(loaded.restore_snapshot(JSON.parse_string(JSON.stringify(manual))), "Both restored utilities survive disk-style JSON")
    assert(loaded.snapshot() == manual, "Utility state equal after restore")

    var fast := MesaState.new()
    fast.examine()
    for stage: int in range(3):
        fast.turn_handwheel()
    fast.make_first_sector_safe()
    assert(bag.try_receive({"capacitor": 1, "coolant_filter": 1}), "Prepare optional region materials")
    assert(fast.replace_power_coupler(bag), "Capacitor shortcut restores power")
    assert(bag.quantity(&"capacitor") == 0 and fast.power_method == "capacitor", "Consumes precisely one capacitor")
    assert(not fast.replace_power_coupler(bag), "Capacitor cannot be duplicated or spent twice")
    assert(fast.replace_flow_filter(bag), "Filter shortcut activates coolant circulation")
    assert(bag.quantity(&"coolant_filter") == 0 and fast.flow_method == "filter", "Consumes precisely one filter")
    assert(not fast.replace_flow_filter(bag), "Filter cannot be spent twice after flow starts")

    var unspoiled: Dictionary = loaded.snapshot()
    var bad: Dictionary = unspoiled.duplicate(true)
    bad["power_method"] = ""
    assert(not loaded.restore_snapshot(bad) and loaded.snapshot() == unspoiled, "Cannot forge flow without power")
    bad = unspoiled.duplicate(true)
    bad["flow_progress"] = 1.5
    assert(not loaded.restore_snapshot(bad) and loaded.snapshot() == unspoiled, "Fractional repair progress rejected")
    bad = unspoiled.duplicate(true)
    bad["first_sector_safe"] = false
    assert(not loaded.restore_snapshot(bad) and loaded.snapshot() == unspoiled, "No repairs with unsafe live electrical bus")
    bad = unspoiled.duplicate(true)
    bad["flow_method"] = "filter"
    assert(not loaded.restore_snapshot(bad) and loaded.snapshot() == unspoiled, "Filter method cannot impersonate manual progress")
    print("PASS: fair manual/part-based mesa utilities, no resource duplicates and atomic persisted dependencies")
    quit(0)
