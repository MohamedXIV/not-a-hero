class_name MesaCarrierPanel
extends Node2D
## A maintenance return line, not a revealed superweapon or final Mesa secret.
## Can be examined and diverted after circulation; both actions are optional.

const LightFactory = preload("res://scripts/presentation/light_factory.gd")
const WORK_MINUTES: float = 15.0
const INTERACT_RADIUS: float = 58.0

var _lamp: PointLight2D


func _ready() -> void:
    _lamp = PointLight2D.new()
    _lamp.texture = LightFactory.radial_texture()
    _lamp.texture_scale = 1.6
    _lamp.color = Color("#81d4c3")
    add_child(_lamp)
    _refresh()


func hint_at(player_position: Vector2) -> String:
    if global_position.distance_to(player_position) >= INTERACT_RADIUS:
        return ""
    if not GameSession.mesa.flow_online():
        return "Service carrier console: the coolant return is still dark."
    if not GameSession.mesa.service_signal_inspected:
        return "E — Read the repeating service-return carrier"
    if GameSession.mesa.service_signal_diverted:
        return "E — Restore the original hatch service return"
    return "E — Send the service return to a harmless reflector"


func interact_at(player_position: Vector2) -> bool:
    if global_position.distance_to(player_position) >= INTERACT_RADIUS:
        return false
    if not GameSession.mesa.flow_online():
        GameSession.report("The return terminal needs working coolant and electricity.")
        return true
    if GameSession.mesa.inspect_service_signal():
        GameSession.notebook.discover("mesa_return_carrier")
        GameSession.speak(&"noticed_mesa_carrier")
        GameSession.report("An unanswered maintenance return. Why would anything still respond?")
        GameSession.save_to_disk()
    elif GameSession.mesa.toggle_service_signal():
        GameSession.advance_time(WORK_MINUTES)
        if GameSession.mesa.service_signal_diverted:
            GameSession.report("The service return follows the old reflector. Nothing needs guarding.")
            GameSession.speak(&"mesa_return_diverted")
        else:
            GameSession.report("The original return line is active again. You can change your mind.")
        GameSession.save_to_disk()
    _refresh()
    return true


func _refresh() -> void:
    if is_instance_valid(_lamp):
        _lamp.energy = 0.65 if GameSession.mesa.flow_online() else 0.0
    queue_redraw()


func _process(_delta: float) -> void:
    if GameSession.mesa.flow_online() and is_instance_valid(_lamp) and _lamp.energy == 0.0:
        _refresh()
    queue_redraw()


func _draw() -> void:
    # Stationary in-world machine console. No GUI-based fake encounter.
    draw_rect(Rect2(-38, -25, 76, 50), Color("#283e43"))
    draw_rect(Rect2(-28, -16, 56, 32), Color("#47646b"))
    var light: Color = Color("#a6dec4") if GameSession.mesa.flow_online() else Color("#6e777a")
    draw_circle(Vector2(-12, -4), 7.0, light)
    draw_line(Vector2(4, 7), Vector2(22, 7), light, 3.0)
    if GameSession.mesa.service_signal_diverted:
        draw_line(Vector2(10, -9), Vector2(23, -12), Color("#f1cf91"), 4.0)
        draw_circle(Vector2(23, -12), 5.0, Color("#f1cf91"))
    else:
        draw_line(Vector2(10, -9), Vector2(10, -16), Color("#9dabb4"), 4.0)
