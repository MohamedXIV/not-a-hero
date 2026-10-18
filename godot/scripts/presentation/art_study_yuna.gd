extends RefCounted
## Author-only procedural art-direction comparisons. These are not production
## sprites. Geometry, movement, scale, color intent and collision stay identical.
## Treatment 1 explores inked silhouettes; 2 explores soft layered surfaces.


static func draw_study(actor: CanvasItem, treatment: int,
        walking: bool, facing_right: bool, ordinary_tic: bool) -> void:
    var ink: bool = treatment == 1
    var edge: Color = Color("#252c32") if ink else Color("#65514f")
    var tunic: Color = Color("#a87f6e") if ink else Color("#bd9488")
    var warm: Color = Color("#e5bda9") if ink else Color("#f0d4bd")
    var braid: Color = Color("#814f3e") if ink else Color("#a36e56")
    var shade: Color = Color("#4e6269") if ink else Color("#7b8291")
    var foot: float = sin(Time.get_ticks_msec() * 0.014) * 2.0 if walking else 0.0
    actor.draw_circle(Vector2(0, 10), 17.0, Color(0.0, 0.0, 0.0, 0.29 if ink else 0.18))
    if not ink:
        actor.draw_circle(Vector2(0, 8), 22.0, Color(0.0, 0.0, 0.0, 0.07))
    for x: float in [-9.0, 9.0]:
        var step: float = foot if x < 0 else -foot
        actor.draw_line(Vector2(x, -7), Vector2(x, 7 + step), edge, 10.0 if ink else 9.0)
        actor.draw_line(Vector2(x, -7), Vector2(x, 6 + step), shade, 6.5)
        actor.draw_circle(Vector2(x, 7 + step), 4.4, Color("#343a42"))
    # Clear torso silhouette at the very same footprint in both styles.
    var coat := PackedVector2Array([
        Vector2(-13, -36), Vector2(13, -36),
        Vector2(20, -7), Vector2(-19, -7),
    ])
    if ink:
        actor.draw_colored_polygon(PackedVector2Array([
            Vector2(-16, -39), Vector2(16, -39),
            Vector2(23, -5), Vector2(-22, -5),
        ]), edge)
    actor.draw_colored_polygon(coat, tunic)
    if ink:
        actor.draw_line(Vector2(-10, -30), Vector2(15, -13), Color("#e2b69b"), 2.5)
        actor.draw_line(Vector2(-4, -36), Vector2(-4, -11), Color("#6c5552"), 2.0)
    else:
        actor.draw_colored_polygon(PackedVector2Array([
            Vector2(-11, -34), Vector2(7, -34), Vector2(4, -10), Vector2(-13, -13)
        ]), Color("#e5bcaa", 0.65))
        actor.draw_arc(Vector2(0, -18), 19, 0.1, PI, 16, Color("#705853", 0.48), 2.0)
    # Arms and practiced, careful hands.
    for side: float in [-1.0, 1.0]:
        var shoulder := Vector2(side * 15.0, -30.0)
        var hand := Vector2(side * 23.0, -13.0)
        actor.draw_line(shoulder, hand, edge if ink else Color("#a47a70"), 8.0)
        actor.draw_line(shoulder, hand, warm, 5.0)
        actor.draw_circle(hand, 3.4, warm)
    actor.draw_circle(Vector2(0, -49), 15.4 if ink else 15.8, edge if ink else braid)
    actor.draw_circle(Vector2(0, -48.3), 13.2, warm)
    if not ink:
        actor.draw_circle(Vector2(-5, -53), 7.5, Color("#f8e0ca", 0.5))
    actor.draw_arc(Vector2(0, -52), 14.8, PI, TAU, 20, braid, 7.5 if ink else 8.0)
    var sign: float = 1.0 if facing_right else -1.0
    var bend: float = 1.0 if ordinary_tic else 0.0
    var p1 := Vector2(sign * 11, -57)
    var p2 := Vector2(sign * (19 + bend * 3), -35)
    var p3 := Vector2(sign * (16 + bend * 4), -23)
    actor.draw_line(p1, p2, edge if ink else braid.darkened(0.17), 10.0)
    actor.draw_line(p1, p2, braid, 7.2)
    actor.draw_line(p2, p3, braid.darkened(0.08), 6.0)
    actor.draw_circle(p3, 4.2, braid)
    actor.draw_line(p3 + Vector2(-3, 0), p3 + Vector2(3, 0), Color("#d7ba87"), 2.0)
    for x: float in [-4.5, 5.0]:
        actor.draw_circle(Vector2(x, -48), 2.1, edge)
        actor.draw_circle(Vector2(x + 0.4, -48.3), 1.0, Color("#8cbd96"))
    actor.draw_line(Vector2(-2, -41), Vector2(2, -40), Color("#aa786f"), 1.6)
