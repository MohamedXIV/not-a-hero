extends Node2D
## In-world furniture placement preview. Nothing happens on an invalid click.
## The main GameSession model owns placements, not this disposable scene.

const LightFactory = preload("res://scripts/presentation/light_factory.gd")

var edit_mode: bool = false
var selected_kind: String = "rug"


func _ready() -> void:
    _rebuild_placed_objects()


func hint() -> String:
    if not edit_mode:
        return "G — Arrange furnishings"
    var display: String = "Rug" if selected_kind == "rug" else "Lantern"
    return "Decor: %s | 1 Rug | 2 Lantern | Click place | X pick up | G done" % display


func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("decorate"):
        edit_mode = not edit_mode
    if not edit_mode:
        return
    if Input.is_action_just_pressed("weapon_pistol"):
        selected_kind = "rug"
    if Input.is_action_just_pressed("weapon_rifle"):
        selected_kind = "lantern"
    if Input.is_action_just_pressed("fire") and get_viewport().gui_get_hovered_control() == null:
        place_at(selected_kind, get_global_mouse_position())
    if Input.is_action_just_pressed("decor_pickup"):
        pickup_at(get_global_mouse_position())
    queue_redraw()


func place_at(kind: String, point: Vector2) -> bool:
    if not GameSession.decor.can_place(kind, point):
        GameSession.report("Not there, Yuna. Keep the hatch and furniture clear.")
        return false
    var info: DecorDefinition = GameSession.decor.definition(kind)
    if info == null or not GameSession.bag.try_spend(info.inventory_item.item_id, 1):
        GameSession.report("You don't have that furnishing in your bag, Yuna.")
        return false
    if not GameSession.decor.place(kind, point):
        GameSession.bag.try_receive({String(info.inventory_item.item_id): 1})
        return false
    GameSession.report("There. Your space, your rules, Yuna.")
    GameSession.save_to_disk()
    _rebuild_placed_objects()
    return true


func pickup_at(point: Vector2) -> bool:
    var index: int = GameSession.decor.at_point(point)
    if index < 0:
        return false
    var placed: Dictionary = GameSession.decor.items()[index]
    var kind: String = String(placed["kind"])
    var info: DecorDefinition = GameSession.decor.definition(kind)
    # Capacity check first. Failed retrieval must leave a lamp in place.
    if not GameSession.bag.try_receive({String(info.inventory_item.item_id): 1}):
        GameSession.report("No room to pick that up, Yuna.")
        return false
    GameSession.decor.remove_at(index)
    GameSession.save_to_disk()
    _rebuild_placed_objects()
    return true


func _rebuild_placed_objects() -> void:
    for child: Node in get_children():
        remove_child(child)
        child.queue_free()
    for entry: Dictionary in GameSession.decor.items():
        var kind: String = String(entry["kind"])
        var info: DecorDefinition = GameSession.decor.definition(kind)
        var center: Vector2 = Vector2(float(entry["x"]), float(entry["y"]))
        if info.obstructs_movement:
            var body := StaticBody2D.new()
            body.position = center
            var shape := RectangleShape2D.new()
            shape.size = info.footprint
            var collision := CollisionShape2D.new()
            collision.shape = shape
            body.add_child(collision)
            add_child(body)
        if info.emits_light:
            var light := PointLight2D.new()
            light.position = center
            light.texture = LightFactory.radial_texture()
            light.texture_scale = 1.7
            light.energy = 0.65
            light.color = Color("#ffbe79")
            add_child(light)
    queue_redraw()


func _draw() -> void:
    for entry: Dictionary in GameSession.decor.items():
        var kind: String = String(entry["kind"])
        var info: DecorDefinition = GameSession.decor.definition(kind)
        var center: Vector2 = Vector2(float(entry["x"]), float(entry["y"]))
        if kind == "rug":
            draw_rect(Rect2(center - info.footprint * 0.5, info.footprint), info.tint)
            draw_rect(Rect2(center - info.footprint * 0.5 + Vector2(6, 6), info.footprint - Vector2(12, 12)), Color("#c89b7a"), false, 3.0)
        else:
            draw_circle(center + Vector2(0, 4), 12.0, Color("#4b453e"))
            draw_circle(center, 7.0, info.tint)
    if edit_mode:
        var current: DecorDefinition = GameSession.decor.definition(selected_kind)
        var center: Vector2 = GameSession.decor.snap_to_grid(get_local_mouse_position())
        var allowed: bool = GameSession.decor.can_place(selected_kind, center)
        var tint: Color = Color(0.52, 0.89, 0.62, 0.52) if allowed else Color(0.95, 0.39, 0.37, 0.55)
        draw_rect(Rect2(center - current.footprint * 0.5, current.footprint), tint, false, 2.0)
