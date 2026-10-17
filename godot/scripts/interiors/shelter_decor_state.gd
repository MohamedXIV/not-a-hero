class_name ShelterDecorState
extends RefCounted
## Persistent validated placements in the *authored* Little Nest interior.
## Fixed fixtures, corridors and the hatch must remain usable after decorating.

const GRID_STEP: float = 16.0
const MAX_PLACED: int = 16
const ROOM: Rect2 = Rect2(78, 104, 505, 362)
const BLOCKED: Array[Rect2] = [
    Rect2(100, 135, 110, 155), # bed and its approach
    Rect2(78, 327, 128, 83),   # cooker
    Rect2(433, 240, 135, 83),  # workbench
    Rect2(447, 134, 100, 74),  # shelf
    Rect2(266, 123, 50, 55),   # water canister
    Rect2(310, 146, 80, 67),   # storage
    Rect2(285, 409, 93, 76),   # exit
    Rect2(275, 295, 106, 111), # clear path to the hatch
]
const DEFINITIONS: Dictionary = {
    "rug": preload("res://resources/decor/rug.tres"),
    "lantern": preload("res://resources/decor/lantern.tres"),
}

var _placements: Array[Dictionary] = []


func definition(kind: String) -> DecorDefinition:
    return DEFINITIONS.get(kind) as DecorDefinition


func snapped(point: Vector2) -> Vector2:
    return Vector2(snappedf(point.x, GRID_STEP), snappedf(point.y, GRID_STEP))


func items() -> Array[Dictionary]:
    return _placements.duplicate(true)


func count_kind(kind: String) -> int:
    var count: int = 0
    for entry: Dictionary in _placements:
        if entry["kind"] == kind:
            count += 1
    return count


func can_place(kind: String, point: Vector2) -> bool:
    var decor: DecorDefinition = definition(kind)
    if decor == null or _placements.size() >= MAX_PLACED:
        return false
    if not is_finite(point.x) or not is_finite(point.y):
        return false
    var placement: Rect2 = Rect2(snapped(point) - decor.footprint * 0.5, decor.footprint)
    if not ROOM.encloses(placement):
        return false
    for forbidden: Rect2 in BLOCKED:
        if placement.intersects(forbidden):
            return false
    for existing: Dictionary in _placements:
        var other: DecorDefinition = definition(String(existing["kind"]))
        var old: Rect2 = Rect2(Vector2(float(existing["x"]), float(existing["y"])) - other.footprint * 0.5, other.footprint)
        if placement.intersects(old):
            return false
    return true


func place(kind: String, point: Vector2) -> bool:
    if not can_place(kind, point):
        return false
    var grid: Vector2 = snapped(point)
    _placements.append({"kind": kind, "x": grid.x, "y": grid.y})
    return true


func at_point(point: Vector2) -> int:
    for i: int in range(_placements.size() - 1, -1, -1):
        var entry: Dictionary = _placements[i]
        var decor: DecorDefinition = definition(String(entry["kind"]))
        var rect: Rect2 = Rect2(Vector2(float(entry["x"]), float(entry["y"])) - decor.footprint * 0.5, decor.footprint)
        if rect.has_point(point):
            return i
    return -1


func remove_at(index: int) -> String:
    if index < 0 or index >= _placements.size():
        return ""
    var kind: String = String(_placements[index]["kind"])
    _placements.remove_at(index)
    return kind


func restore_snapshot(raw: Variant) -> bool:
    if typeof(raw) != TYPE_ARRAY or raw.size() > MAX_PLACED:
        return false
    var candidate := ShelterDecorState.new()
    for entry: Variant in raw:
        if typeof(entry) != TYPE_DICTIONARY:
            return false
        var kind: Variant = entry.get("kind")
        if typeof(kind) != TYPE_STRING:
            return false
        var x: Variant = entry.get("x")
        var y: Variant = entry.get("y")
        if (typeof(x) != TYPE_FLOAT and typeof(x) != TYPE_INT
                or typeof(y) != TYPE_FLOAT and typeof(y) != TYPE_INT):
            return false
        if not is_finite(float(x)) or not is_finite(float(y)):
            return false
        var point: Vector2 = Vector2(float(x), float(y))
        if candidate.snapped(point) != point:
            return false
        if not candidate.place(String(kind), point):
            return false
    _placements = candidate.items()
    return true
