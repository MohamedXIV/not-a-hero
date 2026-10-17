extends Node2D
## Owns level transitions; interiors and exterior do not own persistent session state.

const OUTDOORS: PackedScene = preload("res://scenes/world/outdoors.tscn")
const STARTER_SHELTER: PackedScene = preload("res://scenes/interiors/starter_shelter.tscn")

var _level: Node2D
var _hud: Label
var _last_transition_msec: int = -100000


func _ready() -> void:
    _configure_keys()
    GameSession.load_from_disk()
    _build_hud()
    _open_level(GameSession.current_level)


func _process(delta: float) -> void:
    GameSession.advance_time(delta)
    if Input.is_action_just_pressed("quick_save"):
        GameSession.save_to_disk()
    var hour: int = int(GameSession.day_minutes / 60.0)
    var minute: int = int(GameSession.day_minutes) % 60
    _hud.text = "NOT A HERO  |  %02d:%02d  |  WASD move  Shift sprint  E hatch  F5 save\n" % [hour, minute]
    _hud.text += "Early P0 scene proof • " + ("Little Nest" if GameSession.current_level == "shelter" else "Continuous machine flats")


func _open_level(level_id: String) -> void:
    if is_instance_valid(_level):
        _level.queue_free()
    GameSession.current_level = level_id
    var template: PackedScene = OUTDOORS if level_id == "outdoors" else STARTER_SHELTER
    _level = template.instantiate() as Node2D
    add_child(_level)
    _level.connect("transition_requested", Callable(self, "_on_transition"))


func _on_transition(target: String) -> void:
    # Avoid a single held E key bouncing immediately back through the hatch.
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


func _configure_keys() -> void:
    _ensure_key("move_left", KEY_A)
    _ensure_key("move_right", KEY_D)
    _ensure_key("move_up", KEY_W)
    _ensure_key("move_down", KEY_S)
    _ensure_key("interact", KEY_E)
    _ensure_key("sprint", KEY_SHIFT)
    _ensure_key("quick_save", KEY_F5)


func _ensure_key(action: StringName, key: int) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    for previous: InputEvent in InputMap.action_get_events(action):
        if previous is InputEventKey and previous.physical_keycode == key:
            return
    var event := InputEventKey.new()
    event.physical_keycode = key
    InputMap.action_add_event(action, event)
