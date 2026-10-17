extends Node
## Real scene integrations: subtitles update, event from a workbench and natural tics.

func _ready() -> void:
    call_deferred("_check")


func _check() -> void:
    GameSession.current_level = "shelter"
    GameSession.voice = YunaVoice.new()
    GameSession.condition = YunaCondition.new()
    GameSession.bag = InventoryState.new()
    var main: Node2D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node2D
    add_child(main)
    GameSession.voice = YunaVoice.new()
    var subtitle: Label = main.get("_subtitle") as Label
    if subtitle == null:
        _fail("Subtitle UI missing")
        return
    if not GameSession.speak(&"enemy_spotted"):
        _fail("Could not raise high-priority bark")
        return
    await get_tree().process_frame
    if not subtitle.visible or not subtitle.text.contains("Yuna"):
        _fail("High-priority self-talk not rendered as a subtitle")
        return
    GameSession.voice.subtitles_enabled = false
    await get_tree().process_frame
    if subtitle.visible:
        _fail("Subtitle preference did not hide the label")
        return
    GameSession.voice = YunaVoice.new()
    GameSession.bag.try_receive({"scrap": 3, "wire": 1})
    var shelter: Node2D = main.get("_level") as Node2D
    var bench: Node2D = shelter.get_node("Workbench") as Node2D
    if not bench.call("interact") or GameSession.voice.current_event() != &"craft_success":
        _fail("Actual Workbench did not emit contextual speech")
        return
    var yuna: CharacterBody2D = shelter.get_node("Yuna") as CharacterBody2D
    var tic_before: int = yuna.ordinary_tic_count
    var event_before: StringName = GameSession.voice.current_event()
    GameSession.condition.composure = 0.0
    yuna.call("_advance_ordinary_tic", 23.1)
    if yuna.ordinary_tic_count != tic_before + 1:
        _fail("Natural tic absent when Yuna is distressed")
        return
    GameSession.condition.composure = 100.0
    yuna.call("_advance_ordinary_tic", 23.1)
    if yuna.ordinary_tic_count != tic_before + 2:
        _fail("Natural tic changed frequency when Yuna settled")
        return
    if GameSession.voice.current_event() != event_before:
        _fail("Ordinary tic incorrectly triggered speech or AI")
        return
    print("PASS: real scene contextual bark, subtitle toggle and pressure-independent natural motor tics")
    main.queue_free()
    get_tree().quit(0)


func _fail(message: String) -> void:
    push_error("Yuna speech scene smoke: " + message)
    get_tree().quit(1)
