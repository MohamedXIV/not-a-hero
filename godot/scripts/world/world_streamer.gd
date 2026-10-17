extends Node2D
## Owns only the lifetime of pre-authored chunks near Yuna.
## All changes to authored objects belong in GameSession (stable IDs).

const CHUNK_SIZE: Vector2 = Vector2(640.0, 640.0)
const CHUNK_DEFINITIONS = [
    preload("res://resources/world/chunks/ash_flats.tres"),
    preload("res://resources/world/chunks/cable_edge.tres"),
    preload("res://resources/world/chunks/relay_waste.tres"),
    preload("res://resources/world/chunks/coolant_basin.tres"),
]

@export_range(0, 2) var neighboring_cells: int = 1

var _loaded: Dictionary = {}


func sync_for(world_position: Vector2) -> void:
    var cell := Vector2i(
        floori(world_position.x / CHUNK_SIZE.x),
        floori(world_position.y / CHUNK_SIZE.y)
    )
    for resource: Resource in CHUNK_DEFINITIONS:
        var definition: WorldChunkDefinition = resource as WorldChunkDefinition
        if definition == null or definition.scene == null:
            push_error("An authored chunk Resource is invalid")
            continue
        var near: bool = (absi(definition.grid_cell.x - cell.x) <= neighboring_cells
            and absi(definition.grid_cell.y - cell.y) <= neighboring_cells)
        var key: String = String(definition.chunk_id)
        if near and not _loaded.has(key):
            var chunk: Node2D = definition.scene.instantiate() as Node2D
            chunk.position = Vector2(definition.grid_cell) * CHUNK_SIZE
            add_child(chunk)
            _loaded[key] = chunk
        elif not near and _loaded.has(key):
            var old: Node2D = _loaded[key] as Node2D
            _loaded.erase(key)
            old.queue_free()


func active_chunk_count() -> int:
    return _loaded.size()
