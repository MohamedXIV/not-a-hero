extends Node
## Minimal authoritative state of a session, independent from streamed scene nodes.
## P0 currently models position, clock and persistent world switches only.

const SAVE_PATH: String = "user://not_a_hero_save.json"
const SAVE_VERSION: int = 3
const InputBindings = preload("res://scripts/core/input_bindings.gd")

var current_level: String = "shelter"
var outdoor_position: Vector2 = Vector2(160.0, 330.0)
var shelter_position: Vector2 = Vector2(340.0, 365.0)
var day_minutes: float = 8.0 * 60.0
var world_seed: int = 1573
var world_flags: Dictionary = {}
var bag: InventoryState = InventoryState.new()
var combat_state: Dictionary = {
    "selected": "pistol",
    "pistol": {"clip": 8, "reserve": 32},
    "rifle": {"clip": 4, "reserve": 16},
}
var _feedback: String = ""
var _feedback_until: int = 0


func _ready() -> void:
    InputBindings.install_defaults()


func advance_time(delta: float) -> void:
    # Approximate 24 real minutes per in-game day, provisional balance.
    day_minutes = fposmod(day_minutes + delta, 1440.0)


func report(message: String) -> void:
    _feedback = message
    _feedback_until = Time.get_ticks_msec() + 3500


func current_feedback() -> String:
    return _feedback if Time.get_ticks_msec() < _feedback_until else ""


func get_world_flag(key: StringName) -> bool:
    return bool(world_flags.get(String(key), false))


func set_world_flag(key: StringName, value: bool) -> void:
    world_flags[String(key)] = value


func snapshot() -> Dictionary:
    return {
        "version": SAVE_VERSION,
        "current_level": current_level,
        "outdoor_position": [outdoor_position.x, outdoor_position.y],
        "shelter_position": [shelter_position.x, shelter_position.y],
        "day_minutes": day_minutes,
        "world_seed": world_seed,
        "world_flags": world_flags.duplicate(true),
        "inventory": bag.snapshot(),
        "combat_state": combat_state.duplicate(true),
    }


func restore_snapshot(data: Dictionary) -> bool:
    # Validate *all* fields before changing anything in a running session.
    if int(data.get("version", -1)) != SAVE_VERSION:
        return false
    var level_id: String = str(data.get("current_level", ""))
    if level_id != "shelter" and level_id != "outdoors":
        return false
    var outdoor: Variant = data.get("outdoor_position", [])
    var shelter: Variant = data.get("shelter_position", [])
    if not _valid_point(outdoor) or not _valid_point(shelter):
        return false
    var flags: Variant = data.get("world_flags", {})
    if typeof(flags) != TYPE_DICTIONARY:
        return false
    for flag_id: Variant in flags.keys():
        if typeof(flag_id) != TYPE_STRING or typeof(flags[flag_id]) != TYPE_BOOL:
            return false
    var raw_inventory: Variant = data.get("inventory", null)
    if typeof(raw_inventory) != TYPE_DICTIONARY:
        return false
    var restored_bag := InventoryState.new()
    if not restored_bag.restore_snapshot(raw_inventory as Dictionary):
        return false
    var stored_combat: Variant = data.get("combat_state", null)
    if typeof(stored_combat) != TYPE_DICTIONARY:
        return false
    var combat: Dictionary = stored_combat as Dictionary
    if not _valid_combat_state(combat):
        return false
    var next_combat: Dictionary = {"selected": str(combat["selected"])}
    for name: String in ["pistol", "rifle"]:
        var ammo: Dictionary = combat[name]
        next_combat[name] = {
            "clip": int(ammo["clip"]),
            "reserve": int(ammo["reserve"]),
        }
    var clock: Variant = data.get("day_minutes", 480.0)
    if typeof(clock) != TYPE_FLOAT and typeof(clock) != TYPE_INT:
        return false
    var seed: Variant = data.get("world_seed", 1573)
    if typeof(seed) != TYPE_FLOAT and typeof(seed) != TYPE_INT:
        return false

    current_level = level_id
    outdoor_position = Vector2(float(outdoor[0]), float(outdoor[1]))
    shelter_position = Vector2(float(shelter[0]), float(shelter[1]))
    day_minutes = fposmod(float(clock), 1440.0)
    world_seed = int(seed)
    world_flags = (flags as Dictionary).duplicate(true)
    bag = restored_bag
    combat_state = next_combat
    return true


func _valid_combat_state(data: Dictionary) -> bool:
    if data.get("selected") not in ["pistol", "rifle"]:
        return false
    for weapon_id: String in ["pistol", "rifle"]:
        var candidate: Variant = data.get(weapon_id)
        if typeof(candidate) != TYPE_DICTIONARY:
            return false
        var ammo: Dictionary = candidate as Dictionary
        var magazine_max: int = 8 if weapon_id == "pistol" else 4
        for key: String in ["clip", "reserve"]:
            var value: Variant = ammo.get(key)
            if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
                return false
            var amount: int = int(value)
            if float(value) != float(amount) or amount < 0:
                return false
            if amount > (magazine_max if key == "clip" else 200):
                return false
    return true


func _valid_point(point: Variant) -> bool:
    if typeof(point) != TYPE_ARRAY or point.size() != 2:
        return false
    for coordinate: Variant in point:
        if typeof(coordinate) != TYPE_FLOAT and typeof(coordinate) != TYPE_INT:
            return false
    return true


func save_to_disk(path: String = SAVE_PATH) -> bool:
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        push_warning("Could not open save file: %s" % FileAccess.get_open_error())
        return false
    file.store_string(JSON.stringify(snapshot()))
    file.close()
    return true


func load_from_disk(path: String = SAVE_PATH) -> bool:
    if not FileAccess.file_exists(path):
        return false
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("Ignoring malformed save.")
        return false
    var accepted: bool = restore_snapshot(parsed as Dictionary)
    if not accepted:
        push_warning("Ignoring incompatible or invalid save.")
    return accepted
