extends SceneTree
## P4d: a physical quiet room is optional, supports sleeping independently
## of the court, and grants one authored first-night milestone only once.


func _initialize() -> void:
    call_deferred("_check")


func _opened_mesa() -> MesaState:
    var mesa := MesaState.new()
    assert(mesa.examine(), "Discover physical hatch")
    for step: int in range(MesaState.MANUAL_STAGES):
        assert(mesa.turn_handwheel(), "No luck-dependent entrance")
    assert(mesa.make_first_sector_safe(), "Secure first zone")
    assert(mesa.work_power() and mesa.work_power(), "Manual electricity")
    return mesa


func _check() -> void:
    var mesa := _opened_mesa()
    assert(not mesa.prepare_rear_nook(), "Gallery inaccessible before circulation")
    assert(not mesa.settle_first_night(), "No unearned milestone")
    assert(mesa.work_flow() and mesa.work_flow(), "Manual circulation without loot")
    assert(mesa.prepare_rear_nook(), "Can reclaim acoustic screen without materials")
    assert(not mesa.prepare_rear_nook(), "No repeated restoration")
    assert(not mesa.settle_first_night(), "A prepared cot is NOT automatically home")
    assert(mesa.court_progress == 0, "Cot does not grant or bypass the garden")
    var partial: Dictionary = mesa.snapshot()
    var resumed := MesaState.new()
    assert(resumed.restore_snapshot(JSON.parse_string(JSON.stringify(partial))), "Restored quiet alcove is durable")
    assert(resumed.rear_nook_prepared and not resumed.first_night_spent, "Early rest cannot fake story progress")
    assert(resumed.restore_court_stage() and resumed.restore_court_stage(), "Court may follow nook")
    assert(resumed.settle_first_night(), "Chosen night after nook + green court")
    assert(not resumed.settle_first_night(), "One-time first-night moment cannot farm")
    var stable: Dictionary = resumed.snapshot()
    var loaded := MesaState.new()
    assert(loaded.restore_snapshot(JSON.parse_string(JSON.stringify(stable))), "First-night JSON persists")
    assert(loaded.snapshot() == stable, "Roundtrip is exact")
    for field: String in ["rear_nook_prepared", "first_night_spent"]:
        var wrong: Dictionary = stable.duplicate(true)
        wrong[field] = 1
        assert(not loaded.restore_snapshot(wrong) and loaded.snapshot() == stable, "Wrong type rejected atomically")
    var forged: Dictionary = stable.duplicate(true)
    forged["rear_nook_prepared"] = false
    assert(not loaded.restore_snapshot(forged) and loaded.snapshot() == stable, "Cannot pretend first night without nook")
    forged = stable.duplicate(true)
    forged["court_progress"] = 1
    assert(not loaded.restore_snapshot(forged) and loaded.snapshot() == stable, "Cannot pretend first night before court")
    forged = stable.duplicate(true)
    forged["flow_method"] = ""
    assert(not loaded.restore_snapshot(forged) and loaded.snapshot() == stable, "Nook cannot exist without repaired flow")
    forged = stable.duplicate(true)
    forged.erase("first_night_spent")
    assert(not loaded.restore_snapshot(forged) and loaded.snapshot() == stable, "Missing narrative state rejected")

    # Different discovery/repair order is supported. No mandated quest chain.
    var garden_first := _opened_mesa()
    assert(garden_first.work_flow() and garden_first.work_flow(), "Water ready")
    assert(garden_first.restore_court_stage() and garden_first.restore_court_stage(), "Sun Court first")
    assert(not garden_first.settle_first_night(), "Garden alone is not a chosen night")
    assert(garden_first.prepare_rear_nook() and garden_first.settle_first_night(), "Either order can earn the moment")
    print("PASS: optional restored rear nook, either preparation order, one first night and atomic v15 persistence")
    quit(0)
