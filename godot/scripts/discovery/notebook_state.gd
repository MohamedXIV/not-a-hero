class_name NotebookState
extends RefCounted
## The player's notebook contains only witnessed authored evidence.
## Discoveries are order-independent; missing clues remain absent, not locked.
## UI choice (selection) is transient. Saved facts/pin are validated atomically.

const DEFINITIONS: Dictionary = {
    "ash_warm_conduit": preload("res://resources/discoveries/ash_warm_conduit.tres"),
    "cable_scarred_junction": preload("res://resources/discoveries/cable_scarred_junction.tres"),
    "foundry_shift_cycle": preload("res://resources/discoveries/foundry_shift_cycle.tres"),
    "basin_reverse_flow": preload("res://resources/discoveries/basin_reverse_flow.tres"),
    "cable_eastbound_feeder": preload("res://resources/discoveries/cable_eastbound_feeder.tres"),
    "basin_return_manifold": preload("res://resources/discoveries/basin_return_manifold.tres"),
    "mesa_service_tracks": preload("res://resources/discoveries/mesa_service_tracks.tres"),
    "mesa_return_carrier": preload("res://resources/discoveries/mesa_return_carrier.tres"),
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


# Connections are authored hypotheses, not discovered-object unlocks.
# Each mesa lead is independent and requires only two guaranteed physical clues;
# neither path establishes a door, a code or certain ownership of the site.
const CONNECTIONS: Array[Dictionary] = [
    {
        "id": "power_circuit",
        "sources": ["ash_warm_conduit", "cable_scarred_junction"],
        "text": "Two different traces of an active cable route. They might connect.",
        "mesa_lead": false,
    },
    {
        "id": "shared_pulse",
        "sources": ["foundry_shift_cycle", "basin_reverse_flow"],
        "text": "The press and the siphon both pulse regularly. Could they share a timing signal?",
        "mesa_lead": false,
    },
    {
        "id": "eastern_power",
        "sources": ["ash_warm_conduit", "cable_eastbound_feeder"],
        "text": "That warm conduit may feed the line vanishing into the eastern stone shelf. Is something hidden under the rock still powered?",
        "mesa_lead": true,
    },
    {
        "id": "eastern_service",
        "sources": ["foundry_shift_cycle", "basin_return_manifold"],
        "text": "The press and the return manifold keep time with distant machinery. The return goes beneath the eastern shelf—could there be a working installation?",
        "mesa_lead": true,
    },
    {
        "id": "unanswered_service",
        "sources": ["mesa_service_tracks", "mesa_return_carrier"],
        "text": "Those hatch-side service grooves and the live return carrier match a repeated maintenance approach. Perhaps the machines are answering an old service call, but who sent it and what lies below are still unknown.",
        "mesa_lead": false,
    },
]


func available_connections() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for item: Dictionary in CONNECTIONS:
        var sources: Array = item["sources"]
        if knows(String(sources[0])) and knows(String(sources[1])):
            result.append(item.duplicate(true))
    return result


func related_inferences(id: String) -> Array[String]:
    # Journal pages only show deductions whose evidence includes this page.
    var result: Array[String] = []
    for item: Dictionary in available_connections():
        if (item["sources"] as Array).has(id):
            result.append(String(item["text"]))
    return result


func mesa_leads() -> Array[String]:
    # P4 can use this as an OPTIONAL hint, never as a locked-door predicate.
    var result: Array[String] = []
    for item: Dictionary in available_connections():
        if bool(item["mesa_lead"]):
            result.append(String(item["id"]))
    return result


func inference() -> String:
    var possibilities: Array[String] = []
    for item: Dictionary in available_connections():
        possibilities.append(String(item["text"]))
    return "\n".join(possibilities)


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
