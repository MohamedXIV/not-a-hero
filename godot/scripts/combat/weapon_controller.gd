extends Node2D
## Yuna's intentionally tiny hitscan system. Raycast respects authored cover.
## Weapon stats live in Resources; magazine/reserve live in GameSession.
## No combat while indoors. Full physical injury system arrives in P2.

signal weapon_fired(weapon_id: StringName, hit: bool)

const PISTOL: WeaponDefinition = preload("res://resources/weapons/pistol.tres")
const RIFLE: WeaponDefinition = preload("res://resources/weapons/rifle.tres")

var _cooldown: float = 0.0
var _reload_remaining: float = 0.0
var _last_impact: Vector2 = Vector2.ZERO
var _tracer_remaining: float = 0.0


func _physics_process(delta: float) -> void:
    _cooldown = maxf(0.0, _cooldown - delta)
    if _reload_remaining > 0.0:
        _reload_remaining = maxf(0.0, _reload_remaining - delta)
        if _reload_remaining == 0.0:
            _complete_reload()
    if _tracer_remaining > 0.0:
        _tracer_remaining = maxf(0.0, _tracer_remaining - delta)
        queue_redraw()
    if GameSession.current_level != "outdoors":
        return
    if Input.is_action_just_pressed("weapon_pistol"):
        switch_weapon(&"pistol")
    elif Input.is_action_just_pressed("weapon_rifle"):
        switch_weapon(&"rifle")
    if Input.is_action_just_pressed("reload"):
        start_reload()
    # Clicking the CanvasLayer Save button must not fire or waste a round.
    if Input.is_action_pressed("fire") and get_viewport().gui_get_hovered_control() == null:
        shoot_at(get_global_mouse_position())


func selected_id() -> StringName:
    return StringName(GameSession.combat_state.get("selected", "pistol"))


func definition() -> WeaponDefinition:
    return RIFLE if selected_id() == &"rifle" else PISTOL


func selected_ammo() -> Dictionary:
    var state: Dictionary = GameSession.combat_state.get(String(selected_id()), {})
    return state.duplicate(true)


func switch_weapon(next_id: StringName) -> bool:
    if next_id != &"pistol" and next_id != &"rifle":
        return false
    _reload_remaining = 0.0
    GameSession.combat_state["selected"] = String(next_id)
    return true


func start_reload() -> bool:
    if _reload_remaining > 0.0:
        return false
    var ammo: Dictionary = selected_ammo()
    if int(ammo.get("clip", 0)) >= definition().magazine_size or int(ammo.get("reserve", 0)) < 1:
        return false
    _reload_remaining = definition().reload_seconds
    GameSession.report("Reloading. Breathe, Yuna.")
    return true


func reload_remaining() -> float:
    return _reload_remaining


func _complete_reload() -> void:
    var key: String = String(selected_id())
    var ammo: Dictionary = selected_ammo()
    var missing: int = definition().magazine_size - int(ammo.get("clip", 0))
    var amount: int = mini(missing, int(ammo.get("reserve", 0)))
    if amount <= 0:
        return
    ammo["clip"] = int(ammo["clip"]) + amount
    ammo["reserve"] = int(ammo["reserve"]) - amount
    GameSession.combat_state[key] = ammo


func shoot_at(world_target: Vector2) -> bool:
    if GameSession.current_level != "outdoors" or _cooldown > 0.0 or _reload_remaining > 0.0:
        return false
    var key: String = String(selected_id())
    var ammo: Dictionary = selected_ammo()
    if int(ammo.get("clip", 0)) <= 0:
        GameSession.report("Empty. Reload, Yuna.")
        return false
    var origin: Vector2 = global_position + Vector2(0, -12)
    var vector: Vector2 = world_target - origin
    if vector.length_squared() < 0.01:
        return false
    ammo["clip"] = int(ammo["clip"]) - 1
    GameSession.combat_state[key] = ammo
    _cooldown = definition().fire_interval
    var destination: Vector2 = origin + vector.normalized() * minf(vector.length(), definition().effective_range)
    var query := PhysicsRayQueryParameters2D.create(origin, destination, 1 | 4)
    var ray: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
    var hit: bool = false
    if not ray.is_empty():
        destination = ray["position"] as Vector2
        var body: Object = ray["collider"] as Object
        if body != null and body.has_method("take_damage"):
            body.call("take_damage", definition().damage)
            hit = true
    _last_impact = to_local(destination)
    _tracer_remaining = 0.09
    queue_redraw()
    get_tree().call_group("robot_sensors", "hear_noise", origin, definition().audible_radius)
    weapon_fired.emit(selected_id(), hit)
    return true


func _draw() -> void:
    if _tracer_remaining > 0.0:
        draw_line(Vector2(0, -12), _last_impact, Color("#f9d3a0", 0.8), 2.0)
