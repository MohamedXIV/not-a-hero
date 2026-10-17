extends RefCounted
## Default actions established with the session, not per scene.
## Player may later rebind via InputMap without hardcoded controller branching.

static func install_defaults() -> void:
    _ensure_key(&"move_left", KEY_A)
    _ensure_key(&"move_right", KEY_D)
    _ensure_key(&"move_up", KEY_W)
    _ensure_key(&"move_down", KEY_S)
    _ensure_key(&"interact", KEY_E)
    _ensure_key(&"sprint", KEY_SHIFT)
    _ensure_key(&"quick_save", KEY_F6)
    _ensure_key(&"status_panel", KEY_TAB)
    _ensure_key(&"field_dressing", KEY_F)
    _ensure_key(&"weapon_pistol", KEY_1)
    _ensure_key(&"weapon_rifle", KEY_2)
    _ensure_key(&"reload", KEY_R)
    _ensure_mouse(&"fire", MOUSE_BUTTON_LEFT)


static func _ensure_key(action: StringName, key: int) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    for previous: InputEvent in InputMap.action_get_events(action):
        if previous is InputEventKey and previous.physical_keycode == key:
            return
    var event := InputEventKey.new()
    event.physical_keycode = key
    InputMap.action_add_event(action, event)


static func _ensure_mouse(action: StringName, button: MouseButton) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    for previous: InputEvent in InputMap.action_get_events(action):
        if previous is InputEventMouseButton and previous.button_index == button:
            return
    var event := InputEventMouseButton.new()
    event.button_index = button
    InputMap.action_add_event(action, event)
