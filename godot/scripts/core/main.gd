extends Node2D
## Scene-switching boundary; runtime state is owned by the GameSession autoload.

const OUTDOORS: PackedScene = preload("res://scenes/world/outdoors.tscn")
const STARTER_SHELTER: PackedScene = preload("res://scenes/interiors/starter_shelter.tscn")

var _level: Node2D
var _hud: Label
var _status_detail: Label
var _save_button: Button
var _save_message: String = ""
var _save_message_until: int = 0
var _last_transition_msec: int = -100000


func _ready() -> void:
    var had_save: bool = GameSession.load_from_disk()
    if not had_save:
        # New worlds vary in salvage population, but authored terrain stays fixed.
        GameSession.world_seed = randi()
    _build_hud()
    _open_level(GameSession.current_level)
    if had_save:
        _flash_save_status("Progress restored")


func _process(delta: float) -> void:
    GameSession.advance_time(delta)
    if Input.is_action_just_pressed("quick_save"):
        _write_save()
    var hour: int = int(GameSession.day_minutes / 60.0)
    var minute: int = int(GameSession.day_minutes) % 60
    _hud.text = "NOT A HERO | %02d:%02d | WASD move | Shift sprint | E interact | Tab condition | F6 save\n" % [hour, minute]
    _hud.text += "Little Nest" if GameSession.current_level == "shelter" else "Machine flats — relay: " + ("active" if GameSession.get_world_flag(&"world/ash_flats/relay_01") else "inactive")
    _hud.text += "\nScrap %d  |  Wire %d  |  Relay fuse %d" % [
        GameSession.bag.quantity(&"scrap"),
        GameSession.bag.quantity(&"wire"),
        GameSession.bag.quantity(&"relay_fuse")
    ]
    _hud.text += "\nBag %d/24 | Storage %d/120" % [
        GameSession.bag.total_units(), GameSession.storage.total_units()
    ]
    if GameSession.current_level == "outdoors":
        var selected: String = str(GameSession.combat_state.get("selected", "pistol"))
        var ammo: Dictionary = GameSession.combat_state.get(selected, {})
        _hud.text += "\n1 Pistol | 2 Rifle | Click fire | R reload — %s %d/%d" % [
            selected.capitalize(), int(ammo.get("clip", 0)), int(ammo.get("reserve", 0))
        ]
    var state: YunaCondition = GameSession.condition
    if state.composure < 55.0:
        _hud.text += "\nFeeling %s — find cover or head home" % state.composure_label().to_lower()
    if state.stamina < 48.0:
        _hud.text += "\nOut of breath — slow down"
    if state.injury_description() != "Uninjured":
        _hud.text += "\n" + state.injury_description()
    if state.hydration < 28.0 or state.nourishment < 24.0 or state.fatigue > 72.0:
        _hud.text += "\n" + ("Thirsty " if state.hydration < 28.0 else "") + ("Hungry " if state.nourishment < 24.0 else "") + ("Tired" if state.fatigue > 72.0 else "")
    if Input.is_action_just_pressed("status_panel"):
        _status_detail.visible = not _status_detail.visible
    if _status_detail.visible:
        _status_detail.text = "YUNA — CONDITION\nComposure: %s (%.0f)\nStamina: %.0f\nRest: %.0f/100 tired\nNourishment: %.0f\nHydration: %.0f\n%s\n\nTab closes" % [
            state.composure_label(), state.composure, state.stamina, state.fatigue,
            state.nourishment, state.hydration, state.injury_description()
        ]
    if GameSession.current_feedback() != "":
        _hud.text += "\n" + GameSession.current_feedback()
    if Time.get_ticks_msec() < _save_message_until:
        _hud.text += "\n" + _save_message
    if is_instance_valid(_level) and _level.has_method("get_interaction_hint"):
        var hint: String = _level.call("get_interaction_hint")
        if hint != "":
            _hud.text += "\n" + hint


func _open_level(level_id: String) -> void:
    if is_instance_valid(_level):
        # Remove immediately so old scene cannot process input or update session again.
        remove_child(_level)
        _level.queue_free()
    GameSession.current_level = level_id
    var template: PackedScene = OUTDOORS if level_id == "outdoors" else STARTER_SHELTER
    _level = template.instantiate() as Node2D
    add_child(_level)
    _level.connect("transition_requested", Callable(self, "_on_transition"))


func _on_transition(target: String) -> void:
    var now: int = Time.get_ticks_msec()
    if now - _last_transition_msec < 450:
        return
    _last_transition_msec = now
    _open_level(target)
    GameSession.save_to_disk()


func _build_hud() -> void:
    var overlay := CanvasLayer.new()
    add_child(overlay)
    _hud = Label.new()
    _hud.position = Vector2(20.0, 16.0)
    _hud.add_theme_color_override("font_color", Color("#f5dfba"))
    _hud.add_theme_font_size_override("font_size", 17)
    overlay.add_child(_hud)
    _status_detail = Label.new()
    _status_detail.name = "ConditionDetails"
    _status_detail.position = Vector2(18, 205)
    _status_detail.add_theme_font_size_override("font_size", 20)
    _status_detail.add_theme_color_override("font_color", Color("#f5dfba"))
    _status_detail.visible = false
    overlay.add_child(_status_detail)

    # Genuine save control; browser keys such as F5 may trigger a page reload.
    _save_button = Button.new()
    _save_button.name = "SaveButton"
    _save_button.text = "Save"
    _save_button.size = Vector2(104, 42)
    # CanvasLayer is not a sized Control parent; the TOP_RIGHT preset would
    # apply a viewport anchor plus absolute X, pushing the button offscreen.
    _save_button.position = Vector2(get_viewport_rect().size.x - 128.0, 15.0)
    _save_button.pressed.connect(_write_save)
    overlay.add_child(_save_button)


func _write_save() -> void:
    if GameSession.save_to_disk():
        _flash_save_status("Progress saved")
    else:
        _flash_save_status("Save failed — check storage")


func _flash_save_status(message: String) -> void:
    _save_message = message
    _save_message_until = Time.get_ticks_msec() + 2500
