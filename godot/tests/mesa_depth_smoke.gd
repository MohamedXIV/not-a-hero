extends SceneTree
## P4f: optional physical lower gallery, reversible gentle warmth, strictly
## witnessed archive knowledge and coherent v17 saved world chronology.


func _initialize() -> void:
    call_deferred("_check")


func _opened() -> MesaState:
    var m := MesaState.new()
    assert(m.examine())
    for i: int in range(3):
        assert(m.turn_handwheel())
    assert(m.make_first_sector_safe())
    assert(m.work_power() and m.work_power())
    return m


func _check() -> void:
    var m := _opened()
    assert(not m.unlock_depth(), "Lower chamber requires working pressure release")
    assert(not m.read_depth_archive() and not m.set_depth_warmth(), "Cannot invent lower-level knowledge")
    assert(m.work_flow() and m.work_flow(), "Manual repair remains material-free")
    assert(m.unlock_depth() and not m.unlock_depth(), "One physical lock release")
    assert(not m.set_depth_warmth(), "Must examine protected thermal range first")
    assert(m.read_depth_archive() and not m.read_depth_archive(), "Witness the archive once")
    assert(m.set_depth_warmth() and m.depth_warm, "Choose warmth")
    assert(m.set_depth_warmth() and not m.depth_warm, "Can let cradle cool")
    assert(m.set_depth_warmth() and m.depth_warm, "Can restore warmth later")
    assert(not m.court_restored() and not m.first_night_spent, "No secret progression bypass")
    var stable: Dictionary = m.snapshot()
    var loaded := MesaState.new()
    assert(loaded.restore_snapshot(JSON.parse_string(JSON.stringify(stable))), "v17 lower level JSON")
    assert(loaded.snapshot() == stable, "Exact thermal state restore")
    for field: String in ["depth_open", "depth_archive_read", "depth_warm"]:
        var invalid: Dictionary = stable.duplicate(true)
        invalid[field] = 1
        assert(not loaded.restore_snapshot(invalid) and loaded.snapshot() == stable, "Typed fields")
        invalid = stable.duplicate(true)
        invalid.erase(field)
        assert(not loaded.restore_snapshot(invalid) and loaded.snapshot() == stable, "No missing state")
    var wrong: Dictionary = stable.duplicate(true)
    wrong["flow_method"] = ""
    assert(not loaded.restore_snapshot(wrong) and loaded.snapshot() == stable, "Closed pressure corridor can't have an open lift")
    wrong = stable.duplicate(true)
    wrong["depth_open"] = false
    assert(not loaded.restore_snapshot(wrong) and loaded.snapshot() == stable, "Unentered chamber can't be investigated")
    wrong = stable.duplicate(true)
    wrong["depth_archive_read"] = false
    assert(not loaded.restore_snapshot(wrong) and loaded.snapshot() == stable, "No unearned comfort")
    var note := NotebookState.new()
    assert(note.discover("mesa_thermal_archive"), "Archive is an independently inspectable fact")
    assert(note.related_inferences("mesa_thermal_archive").is_empty(), "No unseen service return leakage")
    assert(not note.knows("mesa_return_carrier"))
    assert(note.discover("mesa_return_carrier"), "Can later inspect the upper service return")
    assert(note.related_inferences("mesa_thermal_archive").size() == 1, "Tentative inference only once both observed")
    assert(note.inference().contains("doesn't identify who"), "Original owner/motive still unknown")
    var reverse := NotebookState.new()
    assert(reverse.discover("mesa_return_carrier") and reverse.discover("mesa_thermal_archive"))
    assert(note.inference() == reverse.inference(), "Observations order-independent")
    assert(reverse.mesa_leads().is_empty(), "No required unlock from archive")
    print("PASS: optional lower gallery, reversible thermal ecology, observed-only inference and atomic v17 persistence")
    quit(0)
