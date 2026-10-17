class_name NotebookState
extends RefCounted
## The player's notebook contains only witnessed authored evidence.
## Discoveries are order-independent; missing clues remain absent, not locked.
## UI choice (selection) is transient. Saved facts/pin are validated atomically.

const DEFINITIONS: Dictionary = {
    "ash_warm_conduit": preload("res://resources/discoveries/ash_warm_conduit.tres"),
    "cable_scarred_junction": preload("res://resources/discoveries/cable_scarred_junction.tres"),
}

var _seen: Array[String] = []
var pinned: String = ""


func definition(id: String) -> DiscoveryDefinition:
    return DEFINITIONS.get(id) as DiscoveryDefinition


func knows(id: String) -> bool:
    return id in _seen


func discover(id: String) -> bool:
    if definition(id) == null or knows(id):
        return false
    _seen.append(id)
    return true


func observed_ids() -> Array[String]:
    return _seen.duplicate()


func pin(id: String) -> bool:
    if not knows(id):
        return false
    pinned = "" if pinned == id else id
    return true


func inference() -> String:
    # This is a deduction from *both* physically observed facts, not new lore.
    if knows("ash_warm_conduit") and knows("cable_scarred_junction"):
        return "Two different traces of an active cable route. They might connect."
    return ""


func snapshot() -> Dictionary:
    return {"observed": _seen.duplicate(), "pinned": pinned}


func restore_snapshot(raw: Dictionary) -> bool:
    var raw_seen: Variant = raw.get("observed", null)
    var raw_pin: Variant = raw.get("pinned", null)
    if typeof(raw_seen) != TYPE_ARRAY or typeof(raw_pin) != TYPE_STRING:
        return false
    if raw_seen.size() > DEFINITIONS.size():
        return false
    var incoming: Array[String] = []
    for entry: Variant in raw_seen:
        if typeof(entry) != TYPE_STRING:
            return false
        var id: String = String(entry)
        if definition(id) == null or id in incoming:
            return false
        incoming.append(id)
    var next_pin: String = String(raw_pin)
    if not next_pin.is_empty() and next_pin not in incoming:
        return false
    _seen = incoming
    pinned = next_pin
    return true
