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
    "noticed_conduit": {
        "priority": 49, "cooldown": 60.0,
        "lines": ["Warm cable. Still powered. Where does it go, Yuna?",
                  "That's not dead wiring. Think, Yuna. Trace it."]
    },
    "noticed_foundry": {
        "priority": 49, "cooldown": 60.0,
        "lines": ["An empty press still keeps time. Who's conducting, Yuna?",
                  "No operators. And yet it cycles. Watch the rhythm, Yuna."]
    },
    "mesa_hatch_found": {
        "priority": 65, "cooldown": 100.0,
        "lines": ["Those gouges... the machines tried to get inside. Why, Yuna?",
                  "A hatch hiding in the rock. You really found something, Yuna."]
    },
    "mesa_access_open": {
        "priority": 70, "cooldown": 100.0,
        "lines": ["That actually worked. You opened it, Yuna.",
                  "Not a miracle. Just engineering. Remember that, Yuna."]
    },
    "mesa_first_look": {
        "priority": 67, "cooldown": 100.0,
        "lines": ["Sunlight... in here? Oh, Yuna. Look at this.",
                  "It's enormous. You can always go home, Yuna."]
    },
    "mesa_power_restored": {
        "priority": 64, "cooldown": 75.0,
        "lines": ["The lights came on. Your hands did that, Yuna.",
                  "A working bus. It's not home yet... but it could be."]
    },
    "mesa_flow_restored": {
        "priority": 66, "cooldown": 75.0,
        "lines": ["Listen. Water moving. The place is waking up, Yuna.",
                  "The barrier lifted. You made it safe, Yuna."]
    },
    "mesa_court_restored": {
        "priority": 65, "cooldown": 110.0,
        "lines": ["Something green. You made room for something alive, Yuna.",
                  "Maybe this place doesn't have to stay a machine, Yuna."]
    },
    "mesa_greens": {
        "priority": 34, "cooldown": 90.0,
        "lines": ["You grew that, Yuna. In real sunlight.",
                  "Just a handful, Yuna. Enough for today."]
    },
    "noticed_mesa_tracks": {
        "priority": 52, "cooldown": 110.0,
        "lines": ["It's coming back to the same marks. Not after you, Yuna.",
                  "Same groove. Same turn. What calls it here, Yuna?"]
    },
    "noticed_mesa_carrier": {
        "priority": 67, "cooldown": 115.0,
        "lines": ["A maintenance return. Still asking for someone, Yuna?",
                  "A service call with no name. That's... a little sad, Yuna."]
    },
    "mesa_return_diverted": {
        "priority": 60, "cooldown": 80.0,
        "lines": ["There. Let them follow a safer line, Yuna.",
                  "You didn't have to hurt it. Just changed where it listens."]
    },
    "mesa_depth_opened": {
        "priority": 65, "cooldown": 90.0,
        "lines": ["More below? You can look, Yuna. You can also leave.",
                  "No weapons. Just a service stair. Still... careful, Yuna."]
    },
    "mesa_thermal_archive": {
        "priority": 70, "cooldown": 145.0,
        "lines": ["It's empty, Yuna. But something kept it warm all this time.",
                  "No name. No message. Only a temperature. Why, Yuna?"]
    },
    "mesa_depth_warm": {
        "priority": 59, "cooldown": 80.0,
        "lines": ["You don't need to know everything to be gentle, Yuna.",
                  "There. Warm enough. Nothing needs saving today."]
    },
    "mesa_rear_nook": {
        "priority": 63, "cooldown": 110.0,
        "lines": ["A screen and a blanket. Small things count, Yuna.",
                  "You can hear the water, not the machinery. Better, Yuna."]
    },
    "mesa_first_night": {
        "priority": 82, "cooldown": 3600.0,
        "lines": ["You slept here, Yuna. You weren't brave. You were just safe.",
                  "This isn't taking Little Nest away, Yuna. You can keep both."]
    },
    "mesa_first_safe": {
        "priority": 70, "cooldown": 100.0,
        "lines": ["One safe room. Maybe the rest can wait, Yuna.",
                  "You did it. And you don't have to move here today."]
    },
    "noticed_east_feeder": {
        "priority": 49, "cooldown": 60.0,
        "lines": ["That feeder heads into the rock. Someone hid the labels, Yuna.",
                  "Current doesn't disappear into stone for no reason. Right, Yuna?"]
    },
    "noticed_return_manifold": {
        "priority": 49, "cooldown": 60.0,
        "lines": ["A return line buried in that shelf? That's odd, Yuna.",
                  "The machines wore a track into the rock. What were they after?"]
    },
    "noticed_basin": {
        "priority": 49, "cooldown": 60.0,
        "lines": ["That's flowing uphill. Pipes don't do that alone, Yuna.",
                  "Something's pulling on this pump. But what?"]
    },
    "noticed_junction": {
        "priority": 49, "cooldown": 60.0,
        "lines": ["Someone erased those markings. Why, Yuna?",
                  "Converging lines... something used to be labeled here."]
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
