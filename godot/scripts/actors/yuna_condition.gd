class_name YunaCondition
extends RefCounted
## A physiological/emotional state, not a health bar or a measure of intelligence.
## Tunable rates are gentle; ordinary tics never change stealth/composure.

const PARTS: Array[String] = ["arm", "leg", "torso"]

var stamina: float = 100.0
var fatigue: float = 8.0
var nourishment: float = 82.0
var hydration: float = 85.0
var composure: float = 78.0
var injuries: Dictionary = {"arm": 0, "leg": 0, "torso": 0}


func tick(delta: float, at_home: bool, moving: bool, sprinting: bool) -> void:
    if delta <= 0.0:
        return
    # One game day is about 24 minutes of real time in the current prototype.
    fatigue = clampf(fatigue + delta * (0.006 if at_home else 0.020), 0.0, 100.0)
    nourishment = clampf(nourishment - delta * 0.012, 0.0, 100.0)
    hydration = clampf(hydration - delta * (0.016 if at_home else 0.023), 0.0, 100.0)
    if sprinting and moving and can_sprint():
        stamina = maxf(0.0, stamina - delta * (17.0 + float(injuries["leg"]) * 3.0))
    else:
        var recovery: float = 14.0 * clampf(1.0 - fatigue * 0.003 - (100.0 - hydration) * 0.003, 0.5, 1.0)
        stamina = minf(100.0, stamina + delta * recovery)
    composure = clampf(composure + delta * (0.32 if at_home else 0.065), 0.0, 100.0)


func apply_pressure(seconds: float) -> void:
    # Sustained readable danger only: no random shocks, screams or tic-triggered reveals.
    if seconds > 0.0:
        composure = maxf(0.0, composure - seconds * 1.55)


func receive_impact(part: StringName = &"leg") -> bool:
    var key: String = String(part)
    if key not in PARTS:
        return false
    injuries[key] = mini(3, int(injuries[key]) + 1)
    composure = maxf(0.0, composure - 11.0)
    stamina = maxf(0.0, stamina - 12.0)
    return true


func can_sprint() -> bool:
    return stamina >= 12.0


func can_focus() -> bool:
    # Temporary task deferral, not lost intelligence. Safe home rest always reverses it.
    return composure >= 18.0


func composure_label() -> String:
    if composure < 18.0:
        return "Overwhelmed"
    if composure < 35.0:
        return "Distressed"
    if composure < 55.0:
        return "Uneasy"
    if composure < 75.0:
        return "Steady"
    return "Settled"


func movement_modifier() -> float:
    # Capped compound penalty: an injured/tired/thirsty Yuna can still reach home.
    var leg_penalty: float = 0.09 * float(injuries["leg"])
    var fatigue_penalty: float = 0.12 if fatigue > 75.0 else 0.0
    var thirst_penalty: float = 0.07 if hydration < 18.0 else 0.0
    return clampf(1.0 - leg_penalty - fatigue_penalty - thirst_penalty, 0.62, 1.0)


func aim_sway_pixels() -> float:
    var pressure: float = maxf(0.0, (55.0 - composure) / 55.0) * 5.0
    return minf(12.0, pressure + float(injuries["arm"]) * 2.0 + (2.0 if fatigue > 80.0 else 0.0))


func reload_modifier() -> float:
    return clampf(1.0 + float(injuries["arm"]) * 0.12 + (0.1 if fatigue > 75.0 else 0.0), 1.0, 1.5)


func injury_description() -> String:
    var names: Array[String] = []
    for part: String in PARTS:
        var severity: int = int(injuries[part])
        if severity == 0:
            continue
        var qualifier: String = "Bruised" if severity == 1 else ("Strained" if severity == 2 else "Seriously injured")
        names.append("%s %s" % [qualifier, part])
    return "Uninjured" if names.is_empty() else ", ".join(names)


func rest_at_home() -> void:
    # Bed is reliable counterplay for panic and fatigue; no mandatory sorties.
    stamina = 100.0
    fatigue = maxf(0.0, fatigue - 45.0)
    composure = minf(100.0, composure + 38.0)
    hydration = maxf(0.0, hydration - 7.0)
    nourishment = maxf(0.0, nourishment - 5.0)
    for part: String in PARTS:
        injuries[part] = maxi(0, int(injuries[part]) - 1)


func snapshot() -> Dictionary:
    return {
        "stamina": stamina,
        "fatigue": fatigue,
        "nourishment": nourishment,
        "hydration": hydration,
        "composure": composure,
        "injuries": injuries.duplicate(true),
    }


func restore_snapshot(raw: Dictionary) -> bool:
    var keys: Array[String] = ["stamina", "fatigue", "nourishment", "hydration", "composure"]
    var normalized: Dictionary = {}
    for key: String in keys:
        var value: Variant = raw.get(key)
        if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
            return false
        var number: float = float(value)
        if not is_finite(number) or number < 0.0 or number > 100.0:
            return false
        normalized[key] = number
    var wounds: Variant = raw.get("injuries")
    if typeof(wounds) != TYPE_DICTIONARY:
        return false
    var restored_wounds: Dictionary = {}
    for part: String in PARTS:
        var severity: Variant = wounds.get(part)
        if typeof(severity) != TYPE_FLOAT and typeof(severity) != TYPE_INT:
            return false
        if not is_finite(float(severity)) or float(severity) != float(int(severity)):
            return false
        if int(severity) < 0 or int(severity) > 3:
            return false
        restored_wounds[part] = int(severity)
    stamina = normalized["stamina"]
    fatigue = normalized["fatigue"]
    nourishment = normalized["nourishment"]
    hydration = normalized["hydration"]
    composure = normalized["composure"]
    injuries = restored_wounds
    return true
