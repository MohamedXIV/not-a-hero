class_name MesaState
extends RefCounted
## The refuge is a world fact and a repairable place, never an objective counter.
## Either physically accessible entry approach works without notebook gates.

const MANUAL_STAGES: int = 3
var inspected: bool = false
var manual_progress: int = 0
var access_method: String = ""
var first_sector_safe: bool = false


func is_open() -> bool:
    return access_method != ""


func examine() -> bool:
    if inspected:
        return false
    inspected = true
    return true


func turn_handwheel() -> bool:
    if not inspected or is_open() or manual_progress >= MANUAL_STAGES:
        return false
    manual_progress += 1
    if manual_progress == MANUAL_STAGES:
        access_method = "manual"
    return true


func install_fuse(bag: InventoryState) -> bool:
    if not inspected or is_open() or bag == null:
        return false
    if not bag.try_spend(&"relay_fuse", 1):
        return false
    access_method = "fuse"
    return true


func make_first_sector_safe() -> bool:
    if not is_open() or first_sector_safe:
        return false
    first_sector_safe = true
    return true


func snapshot() -> Dictionary:
    return {
        "inspected": inspected,
        "manual_progress": manual_progress,
        "access_method": access_method,
        "first_sector_safe": first_sector_safe,
    }


func restore_snapshot(raw: Dictionary) -> bool:
    var looked: Variant = raw.get("inspected")
    var steps: Variant = raw.get("manual_progress")
    var method: Variant = raw.get("access_method")
    var safe: Variant = raw.get("first_sector_safe")
    if typeof(looked) != TYPE_BOOL or typeof(safe) != TYPE_BOOL:
        return false
    if typeof(steps) != TYPE_INT and typeof(steps) != TYPE_FLOAT:
        return false
    if not is_finite(float(steps)) or float(steps) != float(int(steps)):
        return false
    if int(steps) < 0 or int(steps) > MANUAL_STAGES:
        return false
    if typeof(method) != TYPE_STRING or String(method) not in ["", "manual", "fuse"]:
        return false
    if not bool(looked) and (int(steps) > 0 or not String(method).is_empty()):
        return false
    if String(method) == "manual" and int(steps) != MANUAL_STAGES:
        return false
    if String(method) == "" and int(steps) == MANUAL_STAGES:
        return false
    if bool(safe) and String(method).is_empty():
        return false
    inspected = bool(looked)
    manual_progress = int(steps)
    access_method = String(method)
    first_sector_safe = bool(safe)
    return true
