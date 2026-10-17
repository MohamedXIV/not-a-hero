class_name MachineEcology
extends RefCounted
## Coarse offline-compatible machine activity: O(1) calendar lookup per region.
## A region's epoch is derived from monotonic elapsed world minutes, seed and
## region identity. No RNG state or constantly running offscreen SceneTrees.
## Claims are bounded to one most-recent epoch per region (no growing flag log).

const EVENTS: Dictionary = {
    "dead_foundry": preload("res://resources/world/ecology/foundry_reclaimer.tres"),
    "coolant_basin": preload("res://resources/world/ecology/basin_flush.tres"),
}
const MAX_ELAPSED: float = 1000000000.0

var elapsed_minutes: float = 0.0
var _claimed: Dictionary = {
    "dead_foundry": -1,
    "coolant_basin": -1,
}


func definition(region_id: String) -> MachineEventDefinition:
    return EVENTS.get(region_id) as MachineEventDefinition


func advance(minutes: float) -> void:
    if not is_finite(minutes) or minutes <= 0.0:
        return
    elapsed_minutes = minf(MAX_ELAPSED, elapsed_minutes + minutes)


func epoch(region_id: String) -> int:
    var info: MachineEventDefinition = definition(region_id)
    if info == null:
        return -1
    return floori(elapsed_minutes / info.epoch_minutes)


func is_active(region_id: String, seed: int) -> bool:
    var info: MachineEventDefinition = definition(region_id)
    if info == null:
        return false
    var current: int = epoch(region_id)
    # Godot String.hash() is deterministic for a given string in this runtime.
    var token: String = "%s/%d/%d" % [region_id, seed, current]
    return posmod(int(token.hash()), info.active_modulus) == 0


func can_collect(region_id: String, seed: int) -> bool:
    if not is_active(region_id, seed):
        return false
    return int(_claimed.get(region_id, -1)) != epoch(region_id)


func collect(region_id: String, seed: int, bag: InventoryState) -> bool:
    var info: MachineEventDefinition = definition(region_id)
    if info == null or bag == null or info.salvage_item == null:
        return false
    if not can_collect(region_id, seed):
        return false
    # Record claim only after inventory has accepted the entire transfer.
    if not bag.try_receive({String(info.salvage_item.item_id): info.salvage_amount}):
        return false
    _claimed[region_id] = epoch(region_id)
    return true


func snapshot() -> Dictionary:
    return {
        "elapsed_minutes": elapsed_minutes,
        "claimed": _claimed.duplicate(true),
    }


func restore_snapshot(raw: Dictionary) -> bool:
    var elapsed: Variant = raw.get("elapsed_minutes")
    if typeof(elapsed) != TYPE_FLOAT and typeof(elapsed) != TYPE_INT:
        return false
    if not is_finite(float(elapsed)) or float(elapsed) < 0.0 or float(elapsed) > MAX_ELAPSED:
        return false
    var claims: Variant = raw.get("claimed")
    if typeof(claims) != TYPE_DICTIONARY or claims.size() != EVENTS.size():
        return false
    var validated: Dictionary = {}
    for region_id: String in EVENTS.keys():
        var value: Variant = claims.get(region_id)
        if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
            return false
        if not is_finite(float(value)) or float(value) != float(int(value)):
            return false
        var last: int = int(value)
        var max_epoch: int = floori(float(elapsed) / definition(region_id).epoch_minutes)
        if last < -1 or last > max_epoch:
            return false
        validated[region_id] = last
    elapsed_minutes = float(elapsed)
    _claimed = validated
    return true
