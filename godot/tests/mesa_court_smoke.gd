extends SceneTree
## P4c: restoring the sun court is earned after live water, crop grows
## passively and at most one fresh meal waits, even across huge time jumps.

func _initialize() -> void:
    call_deferred("_check")


func _check() -> void:
    var mesa := MesaState.new()
    var body := YunaCondition.new()
    assert(not mesa.restore_court_stage(), "No court restoration before powered circulation")
    mesa.examine()
    for stage: int in range(MesaState.MANUAL_STAGES):
        assert(mesa.turn_handwheel(), "Manual entrance always available")
    assert(mesa.make_first_sector_safe(), "First room secured")
    assert(mesa.work_power() and mesa.work_power(), "Material-free power route")
    assert(not mesa.restore_court_stage(), "Flow must run before plants")
    assert(mesa.work_flow() and mesa.work_flow(), "Material-free coolant route")
    assert(mesa.restore_court_stage() and mesa.court_progress == 1, "First valve repair")
    mesa.advance_court(5000.0)
    assert(not mesa.court_ready, "Unfinished court never generates food")
    var half: Dictionary = mesa.snapshot()
    var resumed := MesaState.new()
    assert(resumed.restore_snapshot(JSON.parse_string(JSON.stringify(half))), "Half-complete court can resume")
    assert(resumed.restore_court_stage() and resumed.court_restored(), "Second valve opens growing court")
    assert(not resumed.restore_court_stage(), "Cannot repeat finished repair")
    resumed.advance_court(719.0)
    assert(not resumed.court_ready, "Growth is time-bounded")
    resumed.advance_court(1.0)
    assert(resumed.court_ready, "Natural growing period produces one meal")
    resumed.advance_court(100000.0)
    assert(resumed.court_ready and resumed.court_grow_minutes == 0.0, "No stockpile after unlimited rest")
    body.nourishment = 100.0
    assert(not resumed.harvest_court(body) and resumed.court_ready, "Full Yuna leaves ready greens untouched")
    body.nourishment = 22.0
    assert(resumed.harvest_court(body) and body.nourishment > 22.0, "Harvest provides actual food")
    assert(not resumed.harvest_court(body), "No instant repeated food")
    resumed.advance_court(720.0)
    assert(resumed.court_ready, "Perennial greens regrow without chores")
    var stable: Dictionary = resumed.snapshot()
    var json: Dictionary = JSON.parse_string(JSON.stringify(stable))
    var loaded := MesaState.new()
    assert(loaded.restore_snapshot(json) and loaded.snapshot() == stable, "Court JSON persistence")
    var invalid: Dictionary = stable.duplicate(true)
    invalid["court_progress"] = 1.5
    assert(not loaded.restore_snapshot(invalid) and loaded.snapshot() == stable, "No fractional work")
    invalid = stable.duplicate(true)
    invalid["court_grow_minutes"] = 25.0
    assert(not loaded.restore_snapshot(invalid) and loaded.snapshot() == stable, "Ready and growing contradictory")
    invalid = stable.duplicate(true)
    invalid["flow_method"] = ""
    assert(not loaded.restore_snapshot(invalid) and loaded.snapshot() == stable, "No living court without water")
    var nest := ShelterDecorState.new()
    var mesa_arrangement := ShelterDecorState.new(true)
    assert(nest.place("rug", Vector2(448, 384)), "Original home unaffected")
    assert(mesa_arrangement.place("rug", Vector2(544, 580)), "Mesa living nook furnished")
    assert(not mesa_arrangement.place("lantern", Vector2(302, 328)), "Cannot block repair console")
    assert(not mesa_arrangement.place("lantern", Vector2(719, 576)), "Must preserve rear access")
    assert(mesa_arrangement.place("lantern", Vector2(640, 600)), "Mesa lighting placed")
    var decor_copy := ShelterDecorState.new(true)
    assert(decor_copy.restore_snapshot(JSON.parse_string(JSON.stringify(mesa_arrangement.items()))), "Mesa decor survives JSON")
    assert(nest.count_kind("lantern") == 0 and decor_copy.count_kind("lantern") == 1, "Independent homes")
    print("PASS: slow single-meal court growth, dependency, atomic v14 state and two independent furnishing layouts")
    quit(0)
