extends SceneTree
## Pure bark scheduler contract: witnessed authored events, urgency, anti-spam,
## settings snapshot validation, and no cloud/random behavior.

func _initialize() -> void:
    call_deferred("_check")


func _check() -> void:
    var voice := YunaVoice.new()
    assert(not voice.offer(&"unknown_discovery"), "No hints for unknown facts")
    assert(voice.offer(&"salvage_found"), "Known salvage observation should speak")
    assert(voice.subtitle().contains("Yuna"), "Yuna addresses herself by name")
    assert(not voice.offer(&"salvage_found"), "One discovery cannot spam speech")
    assert(not voice.offer(&"ate"), "Low-priority events cannot interrupt ongoing line")
    assert(voice.offer(&"enemy_spotted"), "Threat can interrupt idle commentary")
    assert(voice.current_event() == &"enemy_spotted", "Higher-priority threat wins")
    assert(voice.offer(&"injured"), "Injury may preempt a danger line")
    assert(voice.current_event() == &"injured", "Highest priority is retained")
    assert(not voice.offer(&"craft_success"), "Crafting cannot interrupt urgent injury")
    voice.tick(7.0)
    assert(voice.subtitle().is_empty(), "Subtitles automatically expire")
    assert(voice.offer(&"craft_success"), "Character can speak again after cooldown")
    voice.tick(20.0)
    assert(voice.offer(&"craft_success"), "Repeated event allowed after event cooldown")
    assert(voice.subtitle() != "There. One useful thing, Yuna. Nicely done.", "Alternate author-written variants avoid repeats")
    voice.tick(12.0)
    voice.incidental_enabled = false
    assert(not voice.offer(&"home_return"), "Incidental dialogue can be muted")
    assert(voice.offer(&"injured"), "Muting incidental chatter retains essential warnings")
    voice.subtitles_enabled = false
    assert(voice.subtitle().is_empty(), "Subtitle accessibility preference respected")
    var settings: Dictionary = voice.settings_snapshot()
    var restored := YunaVoice.new()
    assert(restored.restore_settings(JSON.parse_string(JSON.stringify(settings))), "Voice preferences survive JSON")
    assert(not restored.incidental_enabled and not restored.subtitles_enabled, "Preferences restored exactly")
    var bad: Dictionary = {"incidental_enabled": true, "subtitles_enabled": "yes"}
    assert(not restored.restore_settings(bad), "Corrupt preference refused")
    assert(restored.settings_snapshot() == settings, "Invalid preference may not mutate state")
    print("PASS: authored self-talk priority, contextual gating, cooldown, variants and accessibility settings")
    quit(0)
