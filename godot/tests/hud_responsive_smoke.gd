extends Node
## P5 HUD acceptance: actual Main controls plus size-driven canvas bounds
## at desktop and compact aspect ratios. This is not a human visual sign-off.

func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node2D
    add_child(main)
    await get_tree().process_frame

    var hud: Label = main.get("_hud") as Label
    var save: Button = main.get("_save_button") as Button
    var prompt: Label = main.get("_interaction_display") as Label
    var subtitle: Label = main.get("_subtitle") as Label
    var feedback: Label = main.get("_feedback_display") as Label
    var notebook: RichTextLabel = main.get("_notebook_display") as RichTextLabel
    var condition: RichTextLabel = main.get("_status_detail") as RichTextLabel
    var controls: RichTextLabel = main.get("_controls_display") as RichTextLabel
    var backdrop: ColorRect = main.get("_panel_backdrop") as ColorRect
    if hud == null or save == null or prompt == null or subtitle == null or feedback == null:
        _fail("Primary HUD elements are missing")
        return
    if notebook == null or condition == null or controls == null or backdrop == null:
        _fail("Scrollable reading overlays are missing")
        return

    for dimensions: Vector2 in [Vector2(1280, 720), Vector2(960, 540), Vector2(640, 360)]:
        main.call("_layout_hud_for_size", dimensions)
        for part: Control in [save, prompt, subtitle, feedback, backdrop, notebook, condition, controls]:
            if part.position.x < 0.0 or part.position.y < 0.0 or part.size.x < 1.0 or part.size.y < 1.0:
                _fail("%s has invalid position or size at %s" % [part.name, dimensions])
                return
            if part.position.x + part.size.x > dimensions.x + 0.1 or part.position.y + part.size.y > dimensions.y + 0.1:
                _fail("%s escapes viewport %s" % [part.name, dimensions])
                return
        if hud.position.x + hud.size.x > dimensions.x - save.size.x:
            _fail("HUD text can occupy Save button's space at %s" % dimensions)
            return
        if not notebook.scroll_active or not condition.scroll_active or not controls.scroll_active:
            _fail("Overlays are not scrollable at narrow viewports")
            return

    # Real mapped physical N, H, Tab key presses activate exactly one panel;
    # subtitles, feedback and focused world prompts yield to the reader.
    await _tap(KEY_N)
    if not notebook.visible or not backdrop.visible or condition.visible or controls.visible:
        _fail("N did not open the Notebook as the only readable overlay")
        return
    await _tap(KEY_H)
    if not controls.visible or notebook.visible or not backdrop.visible:
        _fail("H did not replace the Notebook with controls")
        return
    await _tap(KEY_TAB)
    if not condition.visible or controls.visible or not backdrop.visible:
        _fail("Tab did not replace controls with status")
        return
    await _tap(KEY_TAB)
    if backdrop.visible or notebook.visible or condition.visible or controls.visible:
        _fail("Tab did not close the last overlay")
        return

    main.queue_free()
    print("PASS: P5 HUD remains within desktop/compact viewports; scrollable reading panels toggle with N/H/Tab")
    get_tree().quit(0)


func _tap(key: Key) -> void:
    var down := InputEventKey.new()
    down.physical_keycode = key
    down.pressed = true
    Input.parse_input_event(down)
    await get_tree().process_frame
    await get_tree().process_frame
    var up := InputEventKey.new()
    up.physical_keycode = key
    up.pressed = false
    Input.parse_input_event(up)
    await get_tree().process_frame
    await get_tree().process_frame


func _fail(message: String) -> void:
    push_error("P5 responsive HUD smoke failure: " + message)
    get_tree().quit(1)
