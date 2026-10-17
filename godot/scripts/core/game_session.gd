extends Node
## Runtime-owned cross-scene facts only. No renderer or UI state here.
## P0 intentionally persists only location/time. Versioning starts now.

const SAVE_PATH: String = "user://not_a_hero_save.json"
const SAVE_VERSION: int = 1

var current_level: String = "shelter"
var outdoor_position: Vector2 = Vector2(160.0, 330.0)
var shelter_position: Vector2 = Vector2(340.0, 365.0)
var day_minutes: float = 8.0 * 60.0
var world_seed: int = 1573
# Stable identifier -> authoritative world change, independent from loaded chunk scenes.
var world_flags: Dictionary = {}


func get_world_flag(key: StringName) -> bool:
    return bool(world_flags.get(String(key), false))


func set_world_flag(key: StringName, value: bool) -> void:
    world_flags[String(key)] = value


func advance_time(delta: float) -> void:
    # ~24 real minutes per in-game day: tuning placeholder.
    day_minutes = fposmod(day_minutes + delta, 1440.0)


func save_to_disk() -> bool:
    var state: Dictionary = {
        "version": SAVE_VERSION,
        "current_level": current_level,
        "outdoor_position": [outdoor_position.x, outdoor_position.y],
        "shelter_position": [shelter_position.x, shelter_position.y],
        "day_minutes": day_minutes,
        "world_seed": world_seed,
        "world_flags": world_flags.duplicate(true),
    }
    var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_warning("Could not open save file: %s" % FileAccess.get_open_error())
        return false
    file.store_string(JSON.stringify(state))
    file.close()
    return true


func load_from_disk() -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("Ignoring malformed save.")
        return false
    var data: Dictionary = parsed
    if int(data.get("version", -1)) != SAVE_VERSION:
        push_warning("Ignoring incompatible save version.")
        return false
    var outdoor: Variant = data.get("outdoor_position", [])
    var shelter: Variant = data.get("shelter_position", [])
    if typeof(outdoor) != TYPE_ARRAY or outdoor.size() != 2:
        return false
    if typeof(shelter) != TYPE_ARRAY or shelter.size() != 2:
        return false
    var loaded_level: String = str(data.get("current_level", "shelter"))
    if loaded_level != "shelter" and loaded_level != "outdoors":
        return false
    outdoor_position = Vector2(float(outdoor[0]), float(outdoor[1]))
    shelter_position = Vector2(float(shelter[0]), float(shelter[1]))
    day_minutes = fposmod(float(data.get("day_minutes", 480.0)), 1440.0)
    var flags: Variant = data.get("world_flags", {})
    if typeof(flags) != TYPE_DICTIONARY:
        return false
    # Validate values before trusting a save. P0 changes are simple boolean switches.
    for flag_id: Variant in flags.keys():
        if typeof(flag_id) != TYPE_STRING or typeof(flags[flag_id]) != TYPE_BOOL:
            return false
    world_seed = int(data.get("world_seed", 1573))
    world_flags = (flags as Dictionary).duplicate(true)
    current_level = loaded_level
    return true
