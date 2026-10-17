extends Node2D
## Physical optional maintenance shift. State always belongs to GameSession;
## streaming a chunk in/out must not restart an event or give free loot.

@export var region_id: StringName
@export var worker_scene: PackedScene

var _working: bool = false
var _worker: Node2D


func _ready() -> void:
    add_to_group("world_interactables")
    _sync_activity()
    queue_redraw()


func _process(_delta: float) -> void:
    _sync_activity()


func _sync_activity() -> void:
    var is_working: bool = GameSession.ecology.is_active(String(region_id), GameSession.world_seed)
    if is_working == _working:
        return
    _working = is_working
    if _worker != null:
        _worker.queue_free()
        _worker = null
    if _working and worker_scene != null:
        _worker = worker_scene.instantiate() as Node2D
        _worker.position = Vector2(0.0, -48.0)
        add_child(_worker)
    queue_redraw()


func get_interaction_label() -> String:
    var info: MachineEventDefinition = GameSession.ecology.definition(String(region_id))
    if info == null:
        return ""
    if not _working:
        return "E — Inspect idle %s" % info.display_name
    if GameSession.ecology.can_collect(String(region_id), GameSession.world_seed):
        return "E — Recover parts from %s" % info.display_name
    return "E — Observe completed %s" % info.display_name


func interact() -> bool:
    var info: MachineEventDefinition = GameSession.ecology.definition(String(region_id))
    if info == null:
        return false
    if not _working:
        GameSession.report(info.idle_description)
        return false
    if not GameSession.ecology.can_collect(String(region_id), GameSession.world_seed):
        GameSession.report("Already collected the spare material from this shift.")
        return false
    if not GameSession.ecology.collect(String(region_id), GameSession.world_seed, GameSession.bag):
        GameSession.report("Not enough space for the recovered material, Yuna.")
        return false
    GameSession.report("%s One spare component recovered, Yuna." % info.active_description)
    queue_redraw()
    return true


func _draw() -> void:
    draw_rect(Rect2(-28, -17, 56, 35), Color("#3e4c4b"))
    draw_line(Vector2(-22, 4), Vector2(23, 4), Color("#93a6a3"), 5.0)
    draw_circle(Vector2(12, -9), 5.0, Color("#83d0bd") if _working else Color("#647477"))
    if _working:
        draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 25, Color("#a9d1b8", 0.7), 2.0)
