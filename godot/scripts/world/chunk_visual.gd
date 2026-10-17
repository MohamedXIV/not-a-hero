extends Node2D
## P0 authored geometric chunks; replace visuals with authored TileMapLayers later.
## These positions are fixed world geometry, not randomized terrain.

const LightFactory = preload("res://scripts/presentation/light_factory.gd")
const WIDTH: float = 640.0
const HEIGHT: float = 640.0

@export_range(0, 3) var style: int = 0

const FIXED_OBSTACLES := {
    0: [Vector2(320, 205), Vector2(480, 415)],
    1: [Vector2(175, 180), Vector2(330, 410), Vector2(525, 265)],
    2: [Vector2(200, 420), Vector2(430, 210)],
    3: [Vector2(220, 172), Vector2(472, 290)],
}


func _ready() -> void:
    for point: Vector2 in FIXED_OBSTACLES[style]:
        _make_obstacle(point)
    if style == 3:
        var fixture := PointLight2D.new()
        fixture.position = Vector2(148, 355)
        fixture.texture = LightFactory.radial_texture()
        fixture.texture_scale = 3.0
        fixture.energy = 0.6
        fixture.color = Color("#8dc8d0")
        add_child(fixture)
    if style == 1:
        var fixture := PointLight2D.new()
        fixture.position = Vector2(350, 280)
        fixture.texture = LightFactory.radial_texture()
        fixture.texture_scale = 2.5
        fixture.energy = 0.8
        fixture.color = Color("#8bc1b3")
        add_child(fixture)
    queue_redraw()


func _draw() -> void:
    var grounds: Array[Color] = [
        Color("#666b69"), Color("#4d5961"), Color("#62574c"), Color("#47636a"),
    ]
    var accent: Array[Color] = [
        Color("#8e8470"), Color("#476e72"), Color("#96704c"), Color("#729ba6"),
    ]
    draw_rect(Rect2(Vector2.ZERO, Vector2(WIDTH, HEIGHT)), grounds[style])
    for ix: int in range(0, 11):
        draw_line(Vector2(ix * 64, 0), Vector2(ix * 64, HEIGHT), Color("#262e31", 0.26), 1.0)
    for iy: int in range(0, 11):
        draw_line(Vector2(0, iy * 64), Vector2(WIDTH, iy * 64), Color("#262e31", 0.26), 1.0)
    for point: Vector2 in FIXED_OBSTACLES[style]:
        draw_circle(point + Vector2(8, 12), 34.0, Color(0.0, 0.0, 0.0, 0.18))
        draw_rect(Rect2(point - Vector2(27, 38), Vector2(54, 52)), accent[style])
        draw_line(point - Vector2(24, 32), point + Vector2(23, 7), Color("#222b2e"), 5.0)
    if style == 0:
        draw_line(Vector2(75, 555), Vector2(600, 555), Color("#a18c74"), 10.0)
    elif style == 1:
        for x: int in [80, 460, 585]:
            draw_line(Vector2(x, 0), Vector2(x + 24, 640), Color("#24393d"), 12.0)
    elif style == 2:
        # The Dead Foundry: huge automated presses and cooling rails, not human roads.
        draw_rect(Rect2(300, 54, 246, 63), Color("#433d38"))
        for x: int in [325, 400, 475]:
            draw_line(Vector2(x, 60), Vector2(x, 114), Color("#b7885c"), 8.0)
            draw_circle(Vector2(x, 82), 9.0, Color("#603f34"))
        draw_line(Vector2(0, 334), Vector2(640, 334), Color("#3c3633"), 15.0)
        for x: int in range(24, 640, 65):
            draw_rect(Rect2(x, 325, 28, 18), Color("#987956"))
    else:
        # Coolant Basin: siphons and fluid channels for autonomous machinery.
        # The shelf is solid authored visual geography, not a quest arrow.
        draw_colored_polygon(PackedVector2Array([
            Vector2(394, 0), Vector2(640, 0), Vector2(640, 242),
            Vector2(603, 222), Vector2(584, 282), Vector2(435, 271),
            Vector2(399, 199)
        ]), Color("#394349"))
        draw_line(Vector2(423, 221), Vector2(612, 240), Color("#717069"), 13.0)
        draw_line(Vector2(397, 52), Vector2(560, 91), Color("#757a72"), 10.0)
        draw_line(Vector2(410, 227), Vector2(469, 244), Color("#a08068"), 5.0)
        draw_rect(Rect2(52, 68, 520, 62), Color("#295962"))
        for x: int in [98, 316, 540]:
            draw_line(Vector2(x, 86), Vector2(x, 568), Color("#366f78"), 15.0)
            draw_line(Vector2(x + 12, 86), Vector2(x + 12, 568), Color("#85b3b7"), 4.0)
        draw_arc(Vector2(146, 426), 46, PI, TAU, 18, Color("#88c4cb"), 8.0)


func _make_obstacle(point: Vector2) -> void:
    var solid := StaticBody2D.new()
    solid.position = point
    var collision := CollisionShape2D.new()
    var shape := RectangleShape2D.new()
    shape.size = Vector2(54.0, 40.0)
    collision.shape = shape
    solid.add_child(collision)
    add_child(solid)

    var occluder := LightOccluder2D.new()
    var polygon := OccluderPolygon2D.new()
    polygon.polygon = PackedVector2Array([
        Vector2(-27, -20), Vector2(27, -20),
        Vector2(27, 20), Vector2(-27, 20),
    ])
    occluder.occluder = polygon
    solid.add_child(occluder)
