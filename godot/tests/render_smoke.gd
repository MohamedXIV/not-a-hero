extends Node
## Optional xvfb / Compatibility renderer screen captures; no game code involved.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const SCREENSHOT_DIRECTORY: String = "res://build/screenshots"


func _ready() -> void:
    call_deferred("_capture")


func _capture() -> void:
    var directory: String = ProjectSettings.globalize_path(SCREENSHOT_DIRECTORY)
    if DirAccess.make_dir_recursive_absolute(directory) != OK:
        _fail("Cannot prepare screenshot output directory")
        return

    GameSession.current_level = "shelter"
    GameSession.shelter_position = Vector2(340.0, 365.0)
    var game: Node2D = MAIN_SCENE.instantiate() as Node2D
    add_child(game)
    await RenderingServer.frame_post_draw
    await RenderingServer.frame_post_draw
    if not _save_viewport_image(directory.path_join("starter_shelter.png")):
        return

    GameSession.outdoor_position = Vector2(510.0, 285.0)
    GameSession.day_minutes = 18.0 * 60.0
    game.call("_open_level", "outdoors")
    await RenderingServer.frame_post_draw
    await RenderingServer.frame_post_draw
    if not _save_viewport_image(directory.path_join("outdoors_dusk.png")):
        return
    print("PASS: rendered indoor and outdoor screenshots using Compatibility renderer")
    get_tree().quit(0)


func _save_viewport_image(path: String) -> bool:
    var image: Image = get_viewport().get_texture().get_image()
    if image.is_empty() or image.get_width() < 100 or image.get_height() < 100:
        _fail("Viewport is empty at " + path)
        return false
    var result: Error = image.save_png(path)
    if result != OK:
        _fail("Could not save screenshot at " + path)
        return false
    return true


func _fail(message: String) -> void:
    push_error("Visual smoke failure: " + message)
    get_tree().quit(1)
