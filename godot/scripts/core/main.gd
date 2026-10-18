extends Node2D
## Scene-switching boundary; runtime state is owned by the GameSession autoload.

const OUTDOORS: PackedScene = preload("res://scenes/world/outdoors.tscn")
const STARTER_SHELTER: PackedScene = preload("res://scenes/interiors/starter_shelter.tscn")
const MESA_REFUGE: PackedScene = preload("res://scenes/interiors/mesa_refuge.tscn")
const MESA_DEPTH: PackedScene = preload("res://scenes/interiors/mesa_depth_chamber.tscn")

var _level: Node2D
var _hud: Label
var _status_detail: RichTextLabel
var _subtitle: Label
var _notebook_display: RichTextLabel
var _notebook_page: int = 0
var _controls_display: RichTextLabel
var _panel_backdrop: ColorRect
var _interaction_display: Label
var _feedback_display: Label
var _save_button: Button
var _save_message: String = ""
var _save_message_until: int = 0
var _last_transition_msec: int = -100000
var _transition_requires_release: bool = false


func _ready() -> void:
    var had_save: bool = GameSession.load_from_disk()
    if not had_save:
        # New worlds vary in salvage population, but authored terrain stays fixed.
        GameSession.world_seed = randi()
        GameSession.bag.try_receive({"dressing": 2, "rug": 1, "lantern": 1})
    _build_hud()
    _open_level(GameSession.current_level)
    if had_save:
        _flash_save_status("Progress restored")


func _process(delta: float) -> void:
    # A held E must not bounce Yuna between facing doors. Browser keyboard
    # repeat can outlive the 450ms transition cooldown.
    if _transition_requires_release and not Input.is_action_pressed("interact"):
        _transition_requires_release = false
    GameSession.advance_time(delta)
    if Input.is_action_just_pressed("field_dressing"):
        if GameSession.use_field_dressing():
            GameSession.save_to_disk()
    if Input.is_action_just_pressed("voice_toggle"):
        GameSession.voice.incidental_enabled = not GameSession.voice.incidental_enabled
        GameSession.report("Incidental self-talk: %s" % ("on" if GameSession.voice.incidental_enabled else "off"))
        GameSession.save_to_disk()
    if Input.is_action_just_pressed("subtitle_toggle"):
        GameSession.voice.subtitles_enabled = not GameSession.voice.subtitles_enabled
        GameSession.report("Self-talk subtitles: %s" % ("on" if GameSession.voice.subtitles_enabled else "off"))
        GameSession.save_to_disk()
    if Input.is_action_just_pressed("open_notebook"):
        _toggle_overlay(_notebook_display)
    if _notebook_display.visible:
        if Input.is_action_just_pressed("next_notebook"):
            _notebook_page += 1
        if Input.is_action_just_pressed("pin_notebook"):
            var note_ids: Array[String] = GameSession.notebook.observed_ids()
            if not note_ids.is_empty():
                GameSession.notebook.pin(note_ids[_notebook_page % note_ids.size()])
                GameSession.save_to_disk()
        _update_notebook_display()
    if Input.is_action_just_pressed("quick_save"):
        _write_save()
    if Input.is_action_just_pressed("open_controls"):
        _toggle_overlay(_controls_display)
    var hour: int = int(GameSession.day_minutes / 60.0)
    var minute: int = int(GameSession.day_minutes) % 60
    _hud.text = "NOT A HERO    %02d:%02d    H — Controls\n" % [hour, minute]
    if GameSession.current_level == "shelter":
        _hud.text += "Little Nest"
    elif GameSession.current_level == "mesa_depth":
        _hud.text += "Mesa Refuge — lower service gallery"
    elif GameSession.current_level == "mesa":
        var room_label: String = "first night spent" if GameSession.mesa.first_night_spent else (
            "sun court restored" if GameSession.mesa.court_restored() else (
            "first sector safe" if GameSession.mesa.first_sector_safe else "first sector unpowered"))
        _hud.text += "Mesa Refuge — " + room_label
    else:
        _hud.text += "Machine flats — relay: " + ("active" if GameSession.get_world_flag(&"world/ash_flats/relay_01") else "inactive")
    _hud.text += "\nBag %d/24" % GameSession.bag.total_units()
    if GameSession.current_level == "shelter":
        _hud.text += "   Meals %d  |  Water %d" % [
            int(GameSession.home_supplies["meals"]), int(GameSession.home_supplies["water"])
        ]
    elif GameSession.current_level == "outdoors":
        _hud.text += "   Wire %d  |  Scrap %d  |  Fuse %d" % [
            GameSession.bag.quantity(&"wire"),
            GameSession.bag.quantity(&"scrap"),
            GameSession.bag.quantity(&"relay_fuse")
        ]
    else:
        _hud.text += "   Mesa refuge"

    var state: YunaCondition = GameSession.condition
    if state.composure < 55.0:
        _hud.text += "\nFeeling %s — find cover or head home" % state.composure_label().to_lower()
    if state.stamina < 48.0:
        _hud.text += "\nOut of breath — slow down"
    if state.injury_description() != "Uninjured":
        _hud.text += "\n" + state.injury_description() + " — F first aid"
    if state.hydration < 28.0 or state.nourishment < 24.0 or state.fatigue > 72.0:
        _hud.text += "\n" + ("Thirsty " if state.hydration < 28.0 else "") + ("Hungry " if state.nourishment < 24.0 else "") + ("Tired" if state.fatigue > 72.0 else "")
    if Input.is_action_just_pressed("status_panel"):
        _toggle_overlay(_status_detail)
    if _status_detail.visible:
        _status_detail.text = "YUNA — CONDITION\nComposure: %s (%.0f)\nStamina: %.0f\nRest: %.0f/100 tired\nNourishment: %.0f\nHydration: %.0f\n%s\n\nTab closes" % [
            state.composure_label(), state.composure, state.stamina, state.fatigue,
            state.nourishment, state.hydration, state.injury_description()
        ]
        _status_detail.text += "\nDressings: %d  |  Meals: %d  |  Water: %d" % [
            GameSession.bag.quantity(&"dressing"),
            int(GameSession.home_supplies["meals"]),
            int(GameSession.home_supplies["water"]),
        ]
        _status_detail.text += "\nCondenser: %d ready | Culture: %d ready" % [
            GameSession.production.ready_water, GameSession.production.ready_culture
        ]
        _status_detail.text += "\nV: Incidental remarks %s  |  B: Subtitles %s" % [
            "On" if GameSession.voice.incidental_enabled else "Off",
            "On" if GameSession.voice.subtitles_enabled else "Off",
        ]
    var spoken: String = GameSession.voice.subtitle()
    _subtitle.visible = not spoken.is_empty() and not _panel_backdrop.visible
    if _subtitle.visible:
        _subtitle.text = "Yuna: " + spoken
    var note: String = GameSession.current_feedback()
    if Time.get_ticks_msec() < _save_message_until:
        note = _save_message
    _feedback_display.text = note
    _feedback_display.visible = not note.is_empty() and not _panel_backdrop.visible
    _interaction_display.text = ""
    if is_instance_valid(_level) and _level.has_method("get_interaction_hint"):
        _interaction_display.text = str(_level.call("get_interaction_hint"))
    _interaction_display.visible = not _interaction_display.text.is_empty() and not _panel_backdrop.visible


func _open_level(level_id: String) -> void:
    if is_instance_valid(_level):
        # Remove immediately so old scene cannot process input or update session again.
        remove_child(_level)
        _level.queue_free()
    GameSession.current_level = level_id
    var template: PackedScene = OUTDOORS
    if level_id == "shelter":
        template = STARTER_SHELTER
    elif level_id == "mesa":
        template = MESA_REFUGE
    elif level_id == "mesa_depth":
        template = MESA_DEPTH
    _level = template.instantiate() as Node2D
    add_child(_level)
    _level.connect("transition_requested", Callable(self, "_on_transition"))


func _on_transition(target: String) -> void:
    if _transition_requires_release:
        return
    var now: int = Time.get_ticks_msec()
    if now - _last_transition_msec < 450:
        return
    _last_transition_msec = now
    _transition_requires_release = true
    var previous_level: String = GameSession.current_level
    _open_level(target)
    if target == "shelter":
        GameSession.speak(&"home_return")
    elif target == "mesa" and previous_level != "mesa_depth":
        GameSession.speak(&"mesa_first_look")
    GameSession.save_to_disk()


func _build_hud() -> void:
    var overlay := CanvasLayer.new()
    add_child(overlay)
    _hud = Label.new()
    _hud.position = Vector2(20.0, 16.0)
    _hud.add_theme_color_override("font_color", Color("#f5dfba"))
    _hud.add_theme_font_size_override("font_size", 17)
    overlay.add_child(_hud)

    # Only one scrollable reading panel is active at a time. The backdrop
    # makes important text legible over moving machine geometry.
    _panel_backdrop = ColorRect.new()
    _panel_backdrop.name = "ReadingBackdrop"
    _panel_backdrop.color = Color(0.045, 0.065, 0.075, 0.94)
    _panel_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _panel_backdrop.visible = false
    overlay.add_child(_panel_backdrop)

    # Optional concise controls. Long key legends no longer cover the art
    # every moment of exploration, but remain accessible with H.
    _controls_display = RichTextLabel.new()
    _controls_display.name = "Controls"
    _controls_display.position = Vector2(22, 123)
    _controls_display.add_theme_font_size_override("normal_font_size", 19)
    _controls_display.add_theme_color_override("default_color", Color("#f5dfba"))
    _controls_display.add_theme_color_override("font_shadow_color", Color("#151d22"))
    _controls_display.add_theme_constant_override("shadow_offset_x", 2)
    _controls_display.add_theme_constant_override("shadow_offset_y", 2)
    _controls_display.text = ("WASD  Walk     Shift  Sprint     E  Interact\n"
            + "Q  Optional machine part     G  Arrange     X  Pick up\n"
            + "1 / 2  Weapons     Click  Fire     R  Reload     F  First aid\n"
            + "Tab  Condition     N  Notebook     J  Next     P  Pin\n"
            + "F6  Save     V  Voice     B  Subtitles     H  Close")
    _controls_display.visible = false
    overlay.add_child(_controls_display)

    var viewport_size: Vector2 = get_viewport_rect().size
    _feedback_display = Label.new()
    _feedback_display.name = "ContextFeedback"
    _feedback_display.position = Vector2(23, viewport_size.y - 176)
    _feedback_display.size = Vector2(viewport_size.x - 46, 54)
    _feedback_display.add_theme_font_size_override("font_size", 19)
    _feedback_display.add_theme_color_override("font_color", Color("#f7cf9d"))
    _feedback_display.add_theme_color_override("font_shadow_color", Color("#151d22"))
    _feedback_display.add_theme_constant_override("shadow_offset_x", 2)
    _feedback_display.add_theme_constant_override("shadow_offset_y", 2)
    overlay.add_child(_feedback_display)

    _interaction_display = Label.new()
    _interaction_display.name = "InteractionPrompt"
    _interaction_display.position = Vector2(23, viewport_size.y - 46)
    _interaction_display.size = Vector2(viewport_size.x - 46, 40)
    _interaction_display.add_theme_font_size_override("font_size", 20)
    _interaction_display.add_theme_color_override("font_color", Color("#ffe4af"))
    _interaction_display.add_theme_color_override("font_shadow_color", Color("#111a1e"))
    _interaction_display.add_theme_constant_override("shadow_offset_x", 2)
    _interaction_display.add_theme_constant_override("shadow_offset_y", 2)
    overlay.add_child(_interaction_display)

    _status_detail = RichTextLabel.new()
    _status_detail.name = "ConditionDetails"
    _status_detail.position = Vector2(18, 205)
    _status_detail.add_theme_font_size_override("normal_font_size", 20)
    _status_detail.add_theme_color_override("default_color", Color("#f5dfba"))
    _status_detail.visible = false
    overlay.add_child(_status_detail)

    _subtitle = Label.new()
    _subtitle.name = "YunaSubtitle"
    _subtitle.position = Vector2(180.0, viewport_size.y - 115.0)
    _subtitle.size = Vector2(viewport_size.x - 360.0, 75.0)
    _subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _subtitle.add_theme_font_size_override("font_size", 23)
    _subtitle.add_theme_color_override("font_color", Color("#ffe5c4"))
    _subtitle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
    _subtitle.add_theme_constant_override("shadow_offset_x", 2)
    _subtitle.add_theme_constant_override("shadow_offset_y", 2)
    _subtitle.visible = false
    overlay.add_child(_subtitle)

    _notebook_display = RichTextLabel.new()
    _notebook_display.name = "PersonalNotebook"
    _notebook_display.position = Vector2(380, 82)
    _notebook_display.size = Vector2(575, 410)
    _notebook_display.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _notebook_display.add_theme_font_size_override("normal_font_size", 19)
    _notebook_display.add_theme_color_override("default_color", Color("#f7ddaf"))
    _notebook_display.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
    _notebook_display.add_theme_constant_override("shadow_offset_x", 2)
    _notebook_display.add_theme_constant_override("shadow_offset_y", 2)
    _notebook_display.visible = false
    overlay.add_child(_notebook_display)

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
    get_viewport().size_changed.connect(_layout_hud)
    _layout_hud()


func _toggle_overlay(target: RichTextLabel) -> void:
    var show_panel: bool = not target.visible
    _controls_display.visible = false
    _status_detail.visible = false
    _notebook_display.visible = false
    target.visible = show_panel
    _panel_backdrop.visible = show_panel
    if show_panel:
        target.scroll_to_line(0)


func _layout_hud() -> void:
    _layout_hud_for_size(get_viewport_rect().size)


func _layout_hud_for_size(view_size: Vector2) -> void:
    # The same geometry can be tested at narrow viewports without faking
    # screen sizes or altering Godot's real CanvasLayer/scene transforms.
    var compact: bool = view_size.x < 900.0 or view_size.y < 560.0
    var margin: float = 14.0 if compact else 22.0
    _hud.position = Vector2(margin, 10.0 if compact else 16.0)
    _hud.size = Vector2(maxf(140.0, view_size.x - (148.0 if compact else 190.0)), 150.0)
    _hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _hud.add_theme_font_size_override("font_size", 14 if compact else 17)

    _save_button.size = Vector2(82.0, 34.0) if compact else Vector2(104.0, 42.0)
    _save_button.position = Vector2(view_size.x - margin - _save_button.size.x, margin)

    _feedback_display.position = Vector2(margin, view_size.y - (162.0 if compact else 176.0))
    _feedback_display.size = Vector2(view_size.x - 2.0 * margin, 52.0)
    _feedback_display.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _feedback_display.add_theme_font_size_override("font_size", 16 if compact else 19)

    _subtitle.position = Vector2(margin, view_size.y - (107.0 if compact else 115.0))
    _subtitle.size = Vector2(view_size.x - 2.0 * margin, 57.0 if compact else 75.0)
    _subtitle.add_theme_font_size_override("font_size", 18 if compact else 23)

    _interaction_display.position = Vector2(margin, view_size.y - (46.0 if compact else 46.0))
    _interaction_display.size = Vector2(view_size.x - 2.0 * margin, 40.0)
    _interaction_display.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _interaction_display.add_theme_font_size_override("font_size", 17 if compact else 20)

    var panel_top: float = minf(120.0 if not compact else 104.0, view_size.y * 0.25)
    var panel_width: float = minf(760.0, view_size.x - margin * 2.0)
    _panel_backdrop.position = Vector2((view_size.x - panel_width) / 2.0, panel_top)
    _panel_backdrop.size = Vector2(panel_width, maxf(88.0, view_size.y - panel_top - margin))
    for panel: RichTextLabel in [_controls_display, _status_detail, _notebook_display]:
        panel.position = _panel_backdrop.position + Vector2(14.0, 12.0)
        panel.size = _panel_backdrop.size - Vector2(28.0, 24.0)
        panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        panel.scroll_active = true
        panel.add_theme_font_size_override("normal_font_size", 15 if compact else 19)


func _update_notebook_display() -> void:
    var notes: Array[String] = GameSession.notebook.observed_ids()
    if notes.is_empty():
        _notebook_display.text = "YUNA'S NOTEBOOK\n\nNothing written yet. Look closely at the world.\n\nN close"
        return
    _notebook_page = posmod(_notebook_page, notes.size())
    var id: String = notes[_notebook_page]
    var found: DiscoveryDefinition = GameSession.notebook.definition(id)
    _notebook_display.text = "YUNA'S NOTEBOOK    %d/%d\n%s%s\n\n" % [
        _notebook_page + 1, notes.size(), found.title,
        "  [Pinned]" if GameSession.notebook.pinned == id else ""
    ]
    _notebook_display.text += "What I saw:\n%s\n\nMaybe:\n%s\n\nCould try:\n%s\n\n" % [
        found.observation, found.hypothesis, found.personal_plan
    ]
    var ideas: Array[String] = GameSession.notebook.related_inferences(id)
    if not ideas.is_empty():
        _notebook_display.text += "Connections I can make:\n%s\n\n" % "\n".join(ideas)
    _notebook_display.text += "J next  |  P pin/unpin  |  N close"


func _write_save() -> void:
    if GameSession.save_to_disk():
        _flash_save_status("Progress saved")
    else:
        _flash_save_status("Save failed — check storage")


func _flash_save_status(message: String) -> void:
    _save_message = message
    _save_message_until = Time.get_ticks_msec() + 2500
