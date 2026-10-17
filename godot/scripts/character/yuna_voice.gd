class_name YunaVoice
extends RefCounted
## Authored second-person remarks based ONLY on events Yuna witnessed.
## No LLM, omniscience, random shouting, or connection to stealth detection.
## Per-event cooldown, global pacing and priorities keep her from constantly talking.

const BARKS: Dictionary = {
    "enemy_spotted": {
        "priority": 86, "cooldown": 35.0,
        "lines": ["Yes, Yuna. Stand in the open. Excellent plan.",
                  "That's looking at you. Cover, Yuna. Now."]
    },
    "injured": {
        "priority": 100, "cooldown": 12.0,
        "lines": ["Ow—okay. Move, Yuna. You can worry later.",
                  "That hurt. Find somewhere safe, Yuna."]
    },
    "focus_lost": {
        "priority": 80, "cooldown": 28.0,
        "lines": ["Hands shaking. Not this repair, Yuna. Not yet.",
                  "You know how to do this. Just... not right now."]
    },
    "escaped": {
        "priority": 72, "cooldown": 40.0,
        "lines": ["You're alive, Yuna. Everything's fine... mostly.",
                  "Okay, Yuna. That was close. A little too close."]
    },
    "repair_success": {
        "priority": 55, "cooldown": 22.0,
        "lines": ["It works! See, Yuna? You *do* know what you're doing.",
                  "A working circuit. Yes, Yuna. That's your thing."]
    },
    "craft_success": {
        "priority": 45, "cooldown": 20.0,
        "lines": ["There. One useful thing, Yuna. Nicely done.",
                  "Told you, Yuna. Give yourself a minute to think."]
    },
    "salvage_found": {
        "priority": 42, "cooldown": 35.0,
        "lines": ["Scrap and wiring. You can use this, Yuna.",
                  "Huh. Not garbage after all. Good eyes, Yuna."]
    },
    "care_applied": {
        "priority": 50, "cooldown": 20.0,
        "lines": ["One thing at a time, Yuna. That's better.",
                  "There. Not fixed, but safer. Rest later, Yuna."]
    },
    "home_return": {
        "priority": 48, "cooldown": 42.0,
        "lines": ["Home. Okay, Yuna. You made it back.",
                  "Shut the hatch, Yuna. Just listen to the quiet."]
    },
    "rested": {
        "priority": 32, "cooldown": 45.0,
        "lines": ["Good morning, Yuna. Or... whatever time it is.",
                  "You're allowed to rest, Yuna. Remember that."]
    },
    "ate": {
        "priority": 25, "cooldown": 38.0,
        "lines": ["Something warm. Good thinking, Yuna.",
                  "You remembered to eat, Yuna. Progress."]
    },
    "quiet_ritual": {
        "priority": 28, "cooldown": 80.0,
        "lines": ["There. A little quiet, Yuna. You've earned it.",
                  "Just the radio and you. That's enough for now, Yuna."]
    },
    "drank": {
        "priority": 20, "cooldown": 38.0,
        "lines": ["Water. Sensible, Yuna. Very sensible.",
                  "Hydration first, Yuna. Then the impossible machines."]
    },
}

var incidental_enabled: bool = true
var subtitles_enabled: bool = true

var _clock: float = 0.0
var _active_until: float = 0.0
var _global_cooldown_until: float = 0.0
var _current_priority: int = 0
var _current_event: StringName = &""
var _current_line: String = ""
var _last_event_time: Dictionary = {}
var _variant_counts: Dictionary = {}


func tick(delta: float) -> void:
    _clock += maxf(0.0, delta)
    if _clock >= _active_until:
        _current_line = ""
        _current_event = &""
        _current_priority = 0


func offer(event_id: StringName) -> bool:
    var key: String = String(event_id)
    if not BARKS.has(key):
        return false
    var event: Dictionary = BARKS[key]
    var priority: int = int(event["priority"])
    var essential: bool = priority >= 75
    if not incidental_enabled and not essential:
        return false
    if _clock - float(_last_event_time.get(key, -100000.0)) < float(event["cooldown"]):
        return false
    if not _current_line.is_empty() and priority <= _current_priority:
        return false
    if _clock < _global_cooldown_until and not essential:
        return false
    var variants: Array = event["lines"]
    var next_index: int = int(_variant_counts.get(key, 0)) % variants.size()
    _variant_counts[key] = int(_variant_counts.get(key, 0)) + 1
    _current_line = String(variants[next_index])
    _current_event = event_id
    _current_priority = priority
    _last_event_time[key] = _clock
    _active_until = _clock + clampf(float(_current_line.length()) / 14.0, 3.0, 6.0)
    _global_cooldown_until = _clock + (4.0 if essential else 7.0)
    return true


func subtitle() -> String:
    if not subtitles_enabled or _clock >= _active_until:
        return ""
    return _current_line


func current_event() -> StringName:
    return _current_event if _clock < _active_until else &""


func settings_snapshot() -> Dictionary:
    return {
        "incidental_enabled": incidental_enabled,
        "subtitles_enabled": subtitles_enabled,
    }


func restore_settings(raw: Dictionary) -> bool:
    if typeof(raw.get("incidental_enabled")) != TYPE_BOOL:
        return false
    if typeof(raw.get("subtitles_enabled")) != TYPE_BOOL:
        return false
    incidental_enabled = bool(raw["incidental_enabled"])
    subtitles_enabled = bool(raw["subtitles_enabled"])
    return true
