extends SceneTree
## Mesas are physical, independent of notebook, with two fair access solutions.

func _initialize() -> void:
    call_deferred("_check")


func _check() -> void:
    var fresh := MesaState.new()
    assert(not fresh.is_open() and not fresh.first_sector_safe, "Fresh site remains closed")
    assert(not fresh.turn_handwheel(), "Can't operate before reading physical hatch")
    assert(not fresh.make_first_sector_safe(), "No remote securing inaccessible rooms")
    assert(fresh.examine(), "May inspect hatch without journal or RNG")
    assert(not fresh.examine(), "Repeated examination doesn't reset it")
    assert(fresh.turn_handwheel() and fresh.manual_progress == 1, "Manual pressure released")
    var saved: Dictionary = fresh.snapshot()
    var resumed := MesaState.new()
    assert(resumed.restore_snapshot(JSON.parse_string(JSON.stringify(saved))), "Midway manual work persists")
    assert(resumed.turn_handwheel(), "Can resume latch after save")
    assert(resumed.turn_handwheel() and resumed.is_open(), "Three deterministic handwheel stages open it")
    assert(resumed.access_method == "manual", "Opening method recorded")
    assert(not resumed.turn_handwheel(), "Can't repeat opening forever")
    assert(resumed.make_first_sector_safe(), "First sector may be made safe after opening")
    assert(not resumed.make_first_sector_safe(), "Cannot repeatedly claim sector")
    var bag := InventoryState.new()
    assert(not fresh.install_fuse(bag), "Missing fuse doesn't consume any other resource")
    assert(bag.try_receive({"relay_fuse": 1}), "Spare existing relay fuse acquired")
    assert(fresh.install_fuse(bag), "Alternative fuse bypass works with no notebook")
    assert(fresh.is_open() and fresh.access_method == "fuse", "Fuse opens the same entrance")
    assert(bag.quantity(&"relay_fuse") == 0, "Consumes exactly one relay fuse")
    assert(not fresh.install_fuse(bag), "Cannot duplicate a spent fuse")
    var whole: Dictionary = fresh.snapshot()
    var restored := MesaState.new()
    assert(restored.restore_snapshot(JSON.parse_string(JSON.stringify(whole))), "Fuse route reload")
    assert(restored.snapshot() == whole, "Same valid state")
    var bad: Dictionary = whole.duplicate(true)
    bad["access_method"] = "manual"
    assert(not restored.restore_snapshot(bad), "Can't forge fully manual opening without all stages")
    assert(restored.snapshot() == whole, "Invalid mesa state never mutates live")
    bad = whole.duplicate(true)
    bad["first_sector_safe"] = true
    bad["access_method"] = ""
    assert(not restored.restore_snapshot(bad), "Can't secure a closed entrance")
    print("PASS: no journal gates, two deterministic mesa access routes and validated room state")
    quit(0)
