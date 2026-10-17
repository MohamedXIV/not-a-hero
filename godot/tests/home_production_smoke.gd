extends SceneTree
## No automatic freebies from entering a scene or mashing harvest.

func _initialize() -> void:
    call_deferred("_check")


func _check() -> void:
    var p := HomeProduction.new()
    assert(p.ready_water == 0 and p.ready_culture == 0, "no instantaneous supplies")
    p.advance(239.0)
    assert(p.ready_water == 0, "condenser not ready before four hours")
    p.advance(1.0)
    assert(p.ready_water == 1 and p.ready_culture == 0, "first timed condensation")
    assert(p.take_water() and not p.take_water(), "cannot harvest the same water twice")
    p.advance(240.0)
    assert(p.ready_water == 1 and p.ready_culture == 1, "culture follows eight-hour cycle")
    assert(p.take_culture() and not p.take_culture(), "cannot duplicate ready culture")
    p.advance(99999.0)
    assert(p.ready_water == p.MAX_READY_WATER, "water production is capped")
    assert(p.ready_culture == p.MAX_READY_CULTURE, "culture production is capped")
    assert(p.water_progress == 0.0 and p.culture_progress == 0.0, "full tanks halt progress")
    assert(p.take_water(), "can draw from full condenser")
    p.advance(239.0)
    assert(p.ready_water == p.MAX_READY_WATER - 1, "no instant refill from overflow")
    p.advance(1.0)
    assert(p.ready_water == p.MAX_READY_WATER, "refill takes a real cycle")
    p.mark_unwind()
    assert(not p.can_unwind(), "radio ritual has cooldown")
    p.advance(179.0)
    assert(not p.can_unwind(), "no unlimited button-spam composure")
    p.advance(1.0)
    assert(p.can_unwind(), "ritual can be repeated after time passes")
    var encoded: Variant = JSON.parse_string(JSON.stringify(p.snapshot()))
    var clone := HomeProduction.new()
    assert(clone.restore_snapshot(encoded), "production accepts JSON numbers")
    assert(clone.snapshot() == p.snapshot(), "full production state survives JSON")
    var before: Dictionary = clone.snapshot()
    var broken: Dictionary = before.duplicate(true)
    broken["water_progress"] = -5.0
    assert(not clone.restore_snapshot(broken) and clone.snapshot() == before, "reject negative progress atomically")
    broken = before.duplicate(true)
    broken["ready_culture"] = 2.5
    assert(not clone.restore_snapshot(broken) and clone.snapshot() == before, "reject fractional resource amounts")
    broken = before.duplicate(true)
    broken["ready_water"] = p.MAX_READY_WATER + 1
    assert(not clone.restore_snapshot(broken) and clone.snapshot() == before, "reject over-capacity saves")
    print("PASS: renewable output timing, tank caps, no harvest duplications and save validation")
    quit(0)
