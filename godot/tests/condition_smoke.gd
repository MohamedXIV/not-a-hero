extends SceneTree
## Pure, fast P2 regression: bounded modifiers and reversibility, no random betrayal.

func _initialize() -> void:
    call_deferred("_check")


func _check() -> void:
    var c := YunaCondition.new()
    assert(c.can_focus() and c.can_sprint(), "Yuna begins capable")
    var before: float = c.stamina
    c.tick(2.0, false, true, true)
    assert(c.stamina < before, "Sprinting costs stamina")
    c.tick(3.0, false, false, false)
    assert(c.stamina > before - 34.0, "Walking pause recovers stamina")
    c.apply_pressure(60.0)
    assert(not c.can_focus(), "Extended pursuit interrupts precision work temporarily")
    assert(c.composure_label() == "Overwhelmed", "Stress level is readable")
    for i: int in range(4):
        assert(c.receive_impact(&"leg"), "Valid injury applied")
    c.injuries["arm"] = 3
    c.fatigue = 100.0
    c.hydration = 0.0
    assert(c.movement_modifier() >= 0.62, "All penalties are capped, escape stays possible")
    assert(c.reload_modifier() <= 1.5, "Reload modifiers are bounded")
    assert(c.aim_sway_pixels() <= 12.0, "Aim sway never unbounded")
    var saved: Dictionary = c.snapshot()
    var restored := YunaCondition.new()
    assert(restored.restore_snapshot(JSON.parse_string(JSON.stringify(saved))), "JSON roundtrip")
    assert(int(restored.injuries["leg"]) == 3, "Severe leg injury persists")
    var before_invalid: Dictionary = restored.snapshot()
    var invalid: Dictionary = saved.duplicate(true)
    invalid["injuries"]["arm"] = 2.5
    assert(not restored.restore_snapshot(invalid), "Fractional injuries rejected")
    assert(restored.snapshot() == before_invalid, "Rejected snapshot cannot mutate condition")
    restored.injuries["arm"] = 2
    assert(restored.apply_dressing("arm"), "Valid first aid stabilizes arm")
    assert(not restored.apply_dressing("arm"), "Cannot double-dress same injury")
    assert(restored.bandaged["arm"], "First aid state retained")
    var dressed: Dictionary = restored.snapshot()
    var from_disk := YunaCondition.new()
    assert(from_disk.restore_snapshot(JSON.parse_string(JSON.stringify(dressed))), "Dressing status survives JSON")
    assert(from_disk.bandaged["arm"], "Arm dressing actually restored")
    var bad_care: Dictionary = dressed.duplicate(true)
    bad_care["bandaged"]["leg"] = "maybe"
    assert(not from_disk.restore_snapshot(bad_care), "Malformed care state rejected")
    restored.rest_at_home()
    assert(restored.can_focus(), "The familiar bed restores enough calm to work")
    assert(int(restored.injuries["leg"]) == 2, "Rest heals gradually, never instantly")
    assert(restored.stamina == 100.0, "Sleep restores stamina")
    assert(restored.movement_modifier() >= 0.62, "Still mobile after severe injury")
    var quiet := YunaCondition.new()
    quiet.tick(600.0, true, false, false)
    assert(quiet.can_focus() and quiet.hydration > 60.0, "Quiet shelter time remains viable")
    print("PASS: Yuna stamina, composed focus, safe capped injuries and recovery")
    quit(0)
