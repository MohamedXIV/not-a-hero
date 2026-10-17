class_name HomeProduction
extends RefCounted
## Little Nest's tiny working closed-loop condenser + nutrient culture.
## Production is limited by elapsed game-minutes and ready capacity, so
## walking in/out, clicking or reloading cannot duplicate resources.
## No forced expedition or infinite instantaneous refills.

const WATER_CYCLE: float = 240.0
const CULTURE_CYCLE: float = 480.0
const MAX_READY_WATER: int = 4
const MAX_READY_CULTURE: int = 2
const RITUAL_COOLDOWN: float = 180.0

var water_progress: float = 0.0
var culture_progress: float = 0.0
var ready_water: int = 0
var ready_culture: int = 0
var calm_cooldown: float = 0.0


func advance(minutes: float) -> void:
    if minutes <= 0.0 or not is_finite(minutes):
        return
    calm_cooldown = maxf(0.0, calm_cooldown - minutes)
    if ready_water < MAX_READY_WATER:
        water_progress += minutes
        while water_progress >= WATER_CYCLE and ready_water < MAX_READY_WATER:
            water_progress -= WATER_CYCLE
            ready_water += 1
        if ready_water >= MAX_READY_WATER:
            water_progress = 0.0
    if ready_culture < MAX_READY_CULTURE:
        culture_progress += minutes
        while culture_progress >= CULTURE_CYCLE and ready_culture < MAX_READY_CULTURE:
            culture_progress -= CULTURE_CYCLE
            ready_culture += 1
        if ready_culture >= MAX_READY_CULTURE:
            culture_progress = 0.0


func take_water() -> bool:
    if ready_water <= 0:
        return false
    ready_water -= 1
    return true


func take_culture() -> bool:
    if ready_culture <= 0:
        return false
    ready_culture -= 1
    return true


func can_unwind() -> bool:
    return calm_cooldown <= 0.0


func mark_unwind() -> void:
    calm_cooldown = RITUAL_COOLDOWN


func snapshot() -> Dictionary:
    return {
        "water_progress": water_progress,
        "culture_progress": culture_progress,
        "ready_water": ready_water,
        "ready_culture": ready_culture,
        "calm_cooldown": calm_cooldown,
    }


func restore_snapshot(raw: Dictionary) -> bool:
    for key: String in ["water_progress", "culture_progress", "calm_cooldown"]:
        var value: Variant = raw.get(key)
        if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
            return false
        if not is_finite(float(value)) or float(value) < 0.0:
            return false
    for key: String in ["ready_water", "ready_culture"]:
        var value: Variant = raw.get(key)
        if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
            return false
        if not is_finite(float(value)) or float(value) != float(int(value)):
            return false
    var water: int = int(raw["ready_water"])
    var culture: int = int(raw["ready_culture"])
    if water < 0 or water > MAX_READY_WATER or culture < 0 or culture > MAX_READY_CULTURE:
        return false
    if (float(raw["water_progress"]) >= WATER_CYCLE
            or float(raw["culture_progress"]) >= CULTURE_CYCLE
            or float(raw["calm_cooldown"]) > RITUAL_COOLDOWN):
        return false
    if water == MAX_READY_WATER and float(raw["water_progress"]) != 0.0:
        return false
    if culture == MAX_READY_CULTURE and float(raw["culture_progress"]) != 0.0:
        return false
    water_progress = float(raw["water_progress"])
    culture_progress = float(raw["culture_progress"])
    ready_water = water
    ready_culture = culture
    calm_cooldown = float(raw["calm_cooldown"])
    return true
