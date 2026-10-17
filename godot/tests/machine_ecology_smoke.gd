extends SceneTree
## Coarse-world machine events are functions of elapsed time and world seed,
## with bounded recent claim state rather than a scene or RNG state.

func _initialize() -> void:
    call_deferred("_check")


func _check() -> void:
    var eco := MachineEcology.new()
    var seed: int = 20261017
    var kind: String = "dead_foundry"
    var repeat := MachineEcology.new()
    for n: int in range(18):
        assert(eco.is_active(kind, seed) == repeat.is_active(kind, seed), "Same seed and epoch gives same activity")
        eco.advance(360.0)
        repeat.advance(360.0)
    assert(eco.snapshot() == repeat.snapshot(), "No hidden RNG state or order dependence")
    var before: Dictionary = eco.snapshot()
    eco.advance(-20.0)
    eco.advance(INF)
    assert(eco.snapshot() == before, "Invalid/negative time never rewinds or mutates")
    var sample := MachineEcology.new()
    var found: bool = false
    for i: int in range(30):
        if sample.is_active(kind, seed):
            found = true
            break
        sample.advance(360.0)
    assert(found, "There must be a reachable optional Foundry shift")
    var bag := InventoryState.new()
    assert(bag.try_receive({"scrap": 24}), "Prepare full bag")
    var saved_before: Dictionary = sample.snapshot()
    assert(not sample.collect(kind, seed, bag), "Full bag must reject event rewards")
    assert(sample.snapshot() == saved_before, "Failed collection cannot stamp an epoch")
    bag = InventoryState.new()
    assert(sample.collect(kind, seed, bag), "Known active machine shift should produce one item")
    assert(bag.quantity(&"alloy") == 1, "Reclaimer shift should yield region-specific alloy")
    assert(not sample.collect(kind, seed, bag), "Can't duplicate event reward in same epoch")
    var frame: Dictionary = sample.snapshot()
    var restored := MachineEcology.new()
    assert(restored.restore_snapshot(JSON.parse_string(JSON.stringify(frame))), "Machine calendar accepts JSON save")
    assert(restored.snapshot() == frame, "Claims and elapsed time survive reload")
    assert(not restored.can_collect(kind, seed), "Reloading cannot reset a claimed event")
    restored.advance(360.0)
    var following: int = restored.epoch(kind)
    assert(following > sample.epoch(kind), "Offscreen event period advances by time")
    var bad: Dictionary = frame.duplicate(true)
    bad["claimed"]["dead_foundry"] = 999999
    assert(not restored.restore_snapshot(bad), "Future-epoch claims must be rejected")
    bad = restored.snapshot()
    bad["elapsed_minutes"] = -5.0
    assert(not restored.restore_snapshot(bad), "Negative clock must be rejected")
    assert(restored.epoch(kind) == following, "Failed restore can't reset calendar")
    var quiet := MachineEcology.new()
    quiet.advance(100000.0)
    assert(quiet.epoch("coolant_basin") > 200, "Large offscreen skips are constant time")
    assert(quiet.snapshot()["claimed"].size() == 2, "No unbounded per-epoch claim log")
    print("PASS: seeded offscreen machine epochs, atomic once-per-shift rewards and strict saved clock")
    quit(0)
