extends Node2D
## Side-by-side-in-time playable art review. This scene is launched explicitly
## in the editor, not injected into the actual game or saved state.
## Identical collision, camera, actors, props and lights in both treatments.

const LightFactory = preload("res://scripts/presentation/light_factory.gd")
const ARENA: Rect2 = Rect2(40, 40, 880, 520)
const LAMP: Vector2 = Vector2(238, 218)
const CRATE: Vector2 = Vector2(460, 322)
const PYLON: Vector2 = Vector2(677, 238)
const NAME := {1: "Graphic / Ink", 2: "Soft / Layered"}

@onready var yuna: CharacterBody2D = $Yuna
@onready var ambient: CanvasModulate = $Ambient
var treatment: int = 1
var night: bool = false
var _overlay: Label
var _lamp_light: PointLight2D


func _ready() -> void:
    GameSession.current_level = "shelter"
    yuna.position = Vector2(365, 398)
    var camera: Camera2D = yuna.get_node("Camera2D") as Camera2D
    camera.zoom = Vector2(1.5, 1.5)
    camera.limit_left = 40
    camera.limit_top = 40
    camera.limit_right = 920
    camera.limit_bottom = 560
    for point: Vector2 in [CRATE, PYLON]:
        _place_solid(point, Vector2(70, 37) if point == CRATE else Vector2(56, 38),
            point == PYLON)
    _lamp_light = PointLight2D.new()
    _lamp_light.position = LAMP
    _lamp_light.texture = LightFactory.radial_texture()
    _lamp_light.texture_scale = 3.0
    _lamp_light.energy = 1.0
    _lamp_light.color = Color("#ffd099")
    add_child(_lamp_light)
    var hud := CanvasLayer.new()
    hud.layer = 10
    add_child(hud)
    _overlay = Label.new()
    _overlay.position = Vector2(22, 15)
    _overlay.size = Vector2(1140, 82)
    _overlay.add_theme_color_override("font_color", Color("#fff0db"))
    _overlay.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
    _overlay.add_theme_constant_override("shadow_offset_x", 2)
    _overlay.add_theme_constant_override("shadow_offset_y", 2)
    _overlay.add_theme_font_size_override("font_size", 20)
    hud.add_child(_overlay)
    set_treatment(1)
    set_night(false)


func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    match event.physical_keycode:
        KEY_Z:
            set_treatment(1)
        KEY_X:
            set_treatment(2)
        KEY_T:
            set_night(not night)
        KEY_ESCAPE:
            get_tree().change_scene_to_file("res://scenes/main.tscn")


func set_treatment(value: int) -> void:
    if value not in [1, 2]:
        return
    treatment = value
    yuna.set("art_study_treatment", value)
    _update_label()
    queue_redraw()


func set_night(value: bool) -> void:
    night = value
    ambient.color = Color("#555c6d") if night else Color("#b2a8a1")
    _lamp_light.energy = 1.2 if night else 0.85
    _update_label()
    queue_redraw()


func _update_label() -> void:
    if _overlay != null:
        _overlay.text = ("VISUAL STUDY  |  %s  |  %s\n"
            + "Z: graphic   X: soft   T: day/night   WASD: move   mouse: aim   Esc: return"
            ) % [NAME[treatment], "Night" if night else "Day"]


func _place_solid(point: Vector2, footprint: Vector2, occludes: bool) -> void:
    var solid := StaticBody2D.new()
    solid.position = point
    var shape := RectangleShape2D.new()
    shape.size = footprint
    var col := CollisionShape2D.new()
    col.shape = shape
    solid.add_child(col)
    add_child(solid)
    if occludes:
        var light_block := LightOccluder2D.new()
        var polygon := OccluderPolygon2D.new()
        polygon.polygon = PackedVector2Array([
            Vector2(-28, -19), Vector2(28, -19),
            Vector2(28, 19), Vector2(-28, 19),
        ])
        light_block.occluder = polygon
        solid.add_child(light_block)


func _draw() -> void:
    var graphic: bool = treatment == 1
    var ground: Color = Color("#454c50") if graphic else Color("#5a6463")
    var metal: Color = Color("#586c74") if graphic else Color("#75858b")
    var edge: Color = Color("#172a34") if graphic else Color("#44535a")
    var textile: Color = Color("#b38a73") if graphic else Color("#d0aa91")
    draw_rect(Rect2(Vector2.ZERO, Vector2(960, 600)), Color("#222c32"))
    draw_rect(ARENA, ground)
    if graphic:
        for i: int in range(11):
            draw_line(Vector2(65 + i * 78, 42), Vector2(65 + i * 78, 558), Color("#26343c", 0.6), 1)
    else:
        for i: int in range(15):
            var p := Vector2(80 + i * 57, 80 + (i % 4) * 111)
            draw_circle(p, 19, Color("#c6c0a6", 0.042))
            draw_circle(p + Vector2(9, 4), 9, Color("#202a30", 0.045))
    # Matching 2.5D footprint: warm practical lamp.
    draw_circle(LAMP + Vector2(9, 13), 27, Color(0, 0, 0, 0.22))
    draw_rect(Rect2(LAMP - Vector2(20, 11), Vector2(41, 24)), edge)
    draw_rect(Rect2(LAMP - Vector2(16, 13), Vector2(33, 21)), metal)
    draw_line(LAMP - Vector2(0, 9), LAMP - Vector2(0, 46), edge, 7)
    draw_line(LAMP - Vector2(0, 12), LAMP - Vector2(0, 43), Color("#d0a774"), 4)
    draw_circle(LAMP - Vector2(0, 48), 13, Color("#f6d0a1"))
    if not graphic:
        draw_circle(LAMP - Vector2(0, 47), 9, Color("#fff1c5", 0.65))
    # The same metal crate dimensions and machine-pylon footprint.
    draw_rect(Rect2(CRATE - Vector2(31, 24) + Vector2(7, 10), Vector2(70, 42)), Color(0, 0, 0, 0.25))
    draw_rect(Rect2(CRATE - Vector2(35, 35), Vector2(70, 48)), edge)
    draw_rect(Rect2(CRATE - Vector2(32, 32), Vector2(64, 40)), metal)
    draw_rect(Rect2(CRATE - Vector2(25, 29), Vector2(51, 19)), textile)
    if graphic:
        draw_line(CRATE - Vector2(28, 26), CRATE + Vector2(26, 6), edge, 3)
    else:
        draw_rect(Rect2(CRATE - Vector2(27, 27), Vector2(45, 5)), Color("#e1d1b8", 0.3))
    draw_rect(Rect2(PYLON + Vector2(-20, -95) + Vector2(13, 17), Vector2(58, 121)), Color(0, 0, 0, 0.25))
    draw_rect(Rect2(PYLON - Vector2(28, 94), Vector2(56, 113)), edge)
    draw_rect(Rect2(PYLON - Vector2(25, 90), Vector2(50, 105)), metal)
    for i: int in range(3):
        var y: float = -75.0 + i * 29.0
        draw_line(PYLON + Vector2(-20, y), PYLON + Vector2(20, y), edge, 5.0 if graphic else 3.0)
    draw_circle(PYLON + Vector2(0, -65), 7.0, Color("#b8d1c8"))
    if not graphic:
        draw_rect(Rect2(PYLON + Vector2(-19, -88), Vector2(12, 88)), Color("#d5e3db", 0.18))
