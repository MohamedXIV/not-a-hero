extends Node2D
## Scene-switching boundary; runtime state is owned by the GameSession autoload.

const OUTDOORS: PackedScene = preload("res://scenes/world/outdoors.tscn")
const STARTER_SHELTER: PackedScene = preload("res://scenes/interiors/starter_shelter.tscn")

var _level: Node2D
var _hud: Label
var _last_transition_msec: int = -100000


func _ready() -> void:
    GameSession.load_from_disk()
    _build_hud()
    _open_level(GameSession.current_level)


func _process(delta: float) -> void:
    GameSession.advance_time(delta)
    if Input.is_action_just_pressed("quick_save"):
        GameSession.save_to_disk()
    var hour: int = int(GameSession.day_minutes / 60.0)
    var minute: int = int(GameSession.day_minutes) % 60
    _hud.text = "NOT A HERO | %02d:%02d | WASD move | Shift sprint | E interact | F5 save\n" % [hour, minute]
    _hud.text += "Little Nest" if GameSession.current_level == "shelter" else "Machine flats — relay: " + ("active" if GameSession.get_world_flag(&"world/ash_flats/relay_01") else "inactive")
    if is_instance_valid(_level) and _level.has_method("get_interaction_hint"):
        var hint: String = _level.call("get_interaction_hint")
        if hint != "":
            _hud.text += "\n" + hint


func _open_level(level_id: String) -> void:
    if is_instance_valid(_level):
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
