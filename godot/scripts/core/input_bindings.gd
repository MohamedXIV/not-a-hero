extends RefCounted
## Input registration is a boot dependency, not the responsibility of a HUD/scene.
## Later user key bindings can override these action defaults.


static func install_defaults() -> void:
    _ensure_key(&"move_left", KEY_A)
    _ensure_key(&"move_right", KEY_D)
    _ensure_key(&"move_up", KEY_W)
    _ensure_key(&"move_down", KEY_S)
    _ensure_key(&"interact", KEY_E)
    _ensure_key(&"sprint", KEY_SHIFT)
    _ensure_key(&"quick_save", KEY_F5)


static func _ensure_key(action: StringName, key: int) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    for previous: InputEvent in InputMap.action_get_events(action):
        if previous is InputEventKey and previous.physical_keycode == key:
            return
    var event := InputEventKey.new()
    event.physical_keycode = key
    InputMap.action_add_event(action, event)
