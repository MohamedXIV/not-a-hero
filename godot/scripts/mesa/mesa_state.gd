class_name MesaState
extends RefCounted
## The refuge is a world fact and a repairable place, never an objective counter.
## Either physically accessible entry approach works without notebook gates.

const MANUAL_STAGES: int = 3
const UTILITY_STAGES: int = 2
const WORK_MINUTES: float = 30.0
var inspected: bool = false
var manual_progress: int = 0
var access_method: String = ""
var first_sector_safe: bool = false
var power_progress: int = 0
var power_method: String = ""
var flow_progress: int = 0
var flow_method: String = ""


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


func power_online() -> bool:
    return not power_method.is_empty()


func flow_online() -> bool:
    return not flow_method.is_empty()


func work_power() -> bool:
    if not first_sector_safe or power_online():
        return false
    power_progress += 1
    if power_progress >= UTILITY_STAGES:
        power_method = "manual"
    return true


func replace_power_coupler(bag: InventoryState) -> bool:
    if not first_sector_safe or power_online() or bag == null:
        return false
    if not bag.try_spend(&"capacitor", 1):
        return false
    power_progress = 0
    power_method = "capacitor"
    return true


func work_flow() -> bool:
    if not power_online() or flow_online():
        return false
    flow_progress += 1
    if flow_progress >= UTILITY_STAGES:
        flow_method = "manual"
    return true


func replace_flow_filter(bag: InventoryState) -> bool:
    if not power_online() or flow_online() or bag == null:
        return false
    if not bag.try_spend(&"coolant_filter", 1):
        return false
    flow_progress = 0
    flow_method = "filter"
    return true


func snapshot() -> Dictionary:
    return {
        "inspected": inspected,
        "manual_progress": manual_progress,
        "access_method": access_method,
        "first_sector_safe": first_sector_safe,
        "power_progress": power_progress,
        "power_method": power_method,
        "flow_progress": flow_progress,
        "flow_method": flow_method,
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
    # Utility restore checks run before mutating *any* state.
    var power_step: Variant = raw.get("power_progress")
    var flow_step: Variant = raw.get("flow_progress")
    var power_mode: Variant = raw.get("power_method")
    var flow_mode: Variant = raw.get("flow_method")
    if not _valid_progress(power_step) or not _valid_progress(flow_step):
        return false
    if typeof(power_mode) != TYPE_STRING or typeof(flow_mode) != TYPE_STRING:
        return false
    if String(power_mode) not in ["", "manual", "capacitor"]:
        return false
    if String(flow_mode) not in ["", "manual", "filter"]:
        return false
    if not bool(safe) and (int(power_step) > 0 or String(power_mode) != ""
            or int(flow_step) > 0 or String(flow_mode) != ""):
        return false
    if not _valid_method(String(power_mode), int(power_step), "capacitor"):
        return false
    if not _valid_method(String(flow_mode), int(flow_step), "filter"):
        return false
    if String(power_mode).is_empty() and (int(flow_step) > 0 or not String(flow_mode).is_empty()):
        return false
    inspected = bool(looked)
    manual_progress = int(steps)
    access_method = String(method)
    first_sector_safe = bool(safe)
    power_progress = int(power_step)
    power_method = String(power_mode)
    flow_progress = int(flow_step)
    flow_method = String(flow_mode)


static func _valid_progress(value: Variant) -> bool:
    if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
        return false
    return is_finite(float(value)) and float(value) == float(int(value)) and int(value) >= 0 and int(value) <= UTILITY_STAGES


static func _valid_method(method: String, progress: int, replacement: String) -> bool:
    if method == "manual":
        return progress == UTILITY_STAGES
    if method == replacement:
        return progress == 0
    return progress < UTILITY_STAGES
    return true
