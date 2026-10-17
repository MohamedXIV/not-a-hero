extends Node
## Minimal authoritative state of a session, independent from streamed scene nodes.
## P0 currently models position, clock and persistent world switches only.

const SAVE_PATH: String = "user://not_a_hero_save.json"
const SAVE_VERSION: int = 16
const HOME_SUPPLY_CAP: int = 12
const InputBindings = preload("res://scripts/core/input_bindings.gd")

var current_level: String = "shelter"
var outdoor_position: Vector2 = Vector2(160.0, 330.0)
var shelter_position: Vector2 = Vector2(340.0, 365.0)
var mesa_position: Vector2 = Vector2(217.0, 552.0)
var mesa: MesaState = MesaState.new()
var day_minutes: float = 8.0 * 60.0
var world_seed: int = 1573
var world_flags: Dictionary = {}
var bag: InventoryState = InventoryState.new()
var storage: InventoryState = InventoryState.new(120)
var decor: ShelterDecorState = ShelterDecorState.new()
var mesa_decor: ShelterDecorState = ShelterDecorState.new(true)
var notebook: NotebookState = NotebookState.new()
var ecology: MachineEcology = MachineEcology.new()
var production: HomeProduction = HomeProduction.new()
var condition: YunaCondition = YunaCondition.new()
var voice: YunaVoice = YunaVoice.new()
var home_supplies: Dictionary = {"meals": 4, "water": 6}
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
    production.advance(delta)
    mesa.advance_court(delta)
    ecology.advance(delta)
    voice.tick(delta)


func use_field_dressing() -> bool:
    var part: String = condition.next_untreated_part()
    if part.is_empty():
        report("No untreated injury, Yuna.")
        return false
    if not bag.try_spend(&"dressing", 1):
        report("You need a field dressing, Yuna.")
        return false
    condition.apply_dressing(part)
    speak(&"care_applied")
    report("Easy. That's the %s dressed. Rest when you can." % part)
    return true


func eat_at_home() -> bool:
    if int(home_supplies["meals"]) <= 0 or not condition.eat_meal():
        report("No meal needed or prepared, Yuna.")
        return false
    home_supplies["meals"] = int(home_supplies["meals"]) - 1
    speak(&"ate")
    report("A warm meal. Nice work, Yuna.")
    return true


func drink_at_home() -> bool:
    if int(home_supplies["water"]) <= 0 or not condition.drink_water():
        report("Not thirsty, or the water canister's empty.")
        return false
    home_supplies["water"] = int(home_supplies["water"]) - 1
    speak(&"drank")
    report("Water first. Think clearly, Yuna.")
    return true


func collect_condensed_water() -> bool:
    if current_level != "shelter" or int(home_supplies["water"]) >= HOME_SUPPLY_CAP:
        report("The clean-water canister is full, Yuna.")
        return false
    if not production.take_water():
        report("Still condensing. Give it some time, Yuna.")
        return false
    home_supplies["water"] = int(home_supplies["water"]) + 1
    report("Another clean water portion. Nice and steady.")
    return true


func harvest_culture() -> bool:
    if current_level != "shelter" or int(home_supplies["meals"]) >= HOME_SUPPLY_CAP:
        report("No space for more prepared food, Yuna.")
        return false
    if production.ready_culture <= 0:
        report("The nutrient culture isn't ready, Yuna.")
        return false
    # Commit only once every destination is known to have capacity.
    if not bag.try_receive({"fiber": 1}):
        report("Bag's full. Make room for the culture fibers, Yuna.")
        return false
    production.take_culture()
    home_supplies["meals"] = int(home_supplies["meals"]) + 1
    report("Food and useful fibers. Two things from one tiny garden.")
    return true


func unwind_at_home() -> bool:
    if current_level != "shelter" or not production.can_unwind():
        report("You've only just had a quiet moment, Yuna.")
        return false
    if condition.composure >= 92.0 and condition.fatigue <= 10.0:
        report("You're already settled. Enjoy the quiet, Yuna.")
        return false
    condition.composure = minf(100.0, condition.composure + 16.0)
    condition.fatigue = maxf(0.0, condition.fatigue - 6.0)
    production.mark_unwind()
    production.advance(20.0)
    ecology.advance(20.0)
    day_minutes = fposmod(day_minutes + 20.0, 1440.0)
    speak(&"quiet_ritual")
    report("A few minutes by the radio. The world can wait.")
    return true


func sleep_at_home() -> void:
    condition.rest_at_home()
    speak(&"rested")
    day_minutes = fposmod(day_minutes + 360.0, 1440.0)
    production.advance(360.0)
    mesa.advance_court(360.0)
    ecology.advance(360.0)
    report("Good. You needed that, Yuna.")


func speak(event_id: StringName) -> bool:
    return voice.offer(event_id)


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
        "mesa_position": [mesa_position.x, mesa_position.y],
        "mesa": mesa.snapshot(),
        "day_minutes": day_minutes,
        "world_seed": world_seed,
        "world_flags": world_flags.duplicate(true),
        "inventory": bag.snapshot(),
        "storage": storage.snapshot(),
        "shelter_decor": decor.items(),
        "mesa_decor": mesa_decor.items(),
        "notebook": notebook.snapshot(),
        "ecology": ecology.snapshot(),
        "home_production": production.snapshot(),
        "condition": condition.snapshot(),
        "voice_settings": voice.settings_snapshot(),
        "home_supplies": home_supplies.duplicate(true),
        "combat_state": combat_state.duplicate(true),
    }


func restore_snapshot(data: Dictionary) -> bool:
    # Validate *all* fields before changing anything in a running session.
    if int(data.get("version", -1)) != SAVE_VERSION:
        return false
    var level_id: String = str(data.get("current_level", ""))
    if level_id not in ["shelter", "outdoors", "mesa"]:
        return false
    var outdoor: Variant = data.get("outdoor_position", [])
    var shelter: Variant = data.get("shelter_position", [])
    var mesa_place: Variant = data.get("mesa_position", [])
    if not _valid_point(outdoor) or not _valid_point(shelter) or not _valid_point(mesa_place):
        return false
    var flags: Variant = data.get("world_flags", {})
    if typeof(flags) != TYPE_DICTIONARY:
        return false
    for flag_id: Variant in flags.keys():
        if typeof(flag_id) != TYPE_STRING or typeof(flags[flag_id]) != TYPE_BOOL:
            return false
    var raw_mesa: Variant = data.get("mesa", null)
    if typeof(raw_mesa) != TYPE_DICTIONARY:
        return false
    var restored_mesa := MesaState.new()
    if not restored_mesa.restore_snapshot(raw_mesa as Dictionary):
        return false
    if level_id == "mesa" and not restored_mesa.is_open():
        return false
    var raw_inventory: Variant = data.get("inventory", null)
    if typeof(raw_inventory) != TYPE_DICTIONARY:
        return false
    var restored_bag := InventoryState.new()
    if not restored_bag.restore_snapshot(raw_inventory as Dictionary):
        return false
    var raw_storage: Variant = data.get("storage", null)
    if typeof(raw_storage) != TYPE_DICTIONARY:
        return false
    var restored_storage := InventoryState.new(120)
    if not restored_storage.restore_snapshot(raw_storage as Dictionary):
        return false
    var restored_decor := ShelterDecorState.new()
    if not restored_decor.restore_snapshot(data.get("shelter_decor", null)):
        return false
    var restored_mesa_decor := ShelterDecorState.new(true)
    if not restored_mesa_decor.restore_snapshot(data.get("mesa_decor", null)):
        return false
    var raw_notebook: Variant = data.get("notebook", null)
    if typeof(raw_notebook) != TYPE_DICTIONARY:
        return false
    var restored_notebook := NotebookState.new()
    if not restored_notebook.restore_snapshot(raw_notebook as Dictionary):
        return false
    var raw_ecology: Variant = data.get("ecology", null)
    if typeof(raw_ecology) != TYPE_DICTIONARY:
        return false
    var restored_ecology := MachineEcology.new()
    if not restored_ecology.restore_snapshot(raw_ecology as Dictionary):
        return false
    var raw_production: Variant = data.get("home_production", null)
    if typeof(raw_production) != TYPE_DICTIONARY:
        return false
    var restored_production := HomeProduction.new()
    if not restored_production.restore_snapshot(raw_production as Dictionary):
        return false
    var raw_condition: Variant = data.get("condition")
    if typeof(raw_condition) != TYPE_DICTIONARY:
        return false
    var restored_condition := YunaCondition.new()
    if not restored_condition.restore_snapshot(raw_condition as Dictionary):
        return false
    var supplies: Variant = data.get("home_supplies")
    if typeof(supplies) != TYPE_DICTIONARY:
        return false
    var restored_supplies: Dictionary = {}
    for supply_id: String in ["meals", "water"]:
        var quantity: Variant = supplies.get(supply_id)
        if typeof(quantity) != TYPE_FLOAT and typeof(quantity) != TYPE_INT:
            return false
        if not is_finite(float(quantity)) or float(quantity) != float(int(quantity)):
            return false
        if int(quantity) < 0 or int(quantity) > HOME_SUPPLY_CAP:
            return false
        restored_supplies[supply_id] = int(quantity)
    var raw_voice: Variant = data.get("voice_settings")
    if typeof(raw_voice) != TYPE_DICTIONARY:
        return false
    var restored_voice := YunaVoice.new()
    if not restored_voice.restore_settings(raw_voice as Dictionary):
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
    mesa_position = Vector2(float(mesa_place[0]), float(mesa_place[1]))
    mesa = restored_mesa
    day_minutes = fposmod(float(clock), 1440.0)
    world_seed = int(seed)
    world_flags = (flags as Dictionary).duplicate(true)
    bag = restored_bag
    storage = restored_storage
    decor = restored_decor
    mesa_decor = restored_mesa_decor
    notebook = restored_notebook
    ecology = restored_ecology
    production = restored_production
    condition = restored_condition
    voice = restored_voice
    home_supplies = restored_supplies
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
