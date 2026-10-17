class_name LootTableDefinition
extends Resource
## Deterministic content on an authored map. No randomness affects geometry.
## A container's opened state is persisted separately under its stable world ID.

@export var table_id: StringName
@export_range(1, 6) var draws: int = 2
@export var entries: Array[LootEntryDefinition] = []


func roll(world_seed: int, container_id: StringName) -> Dictionary:
    if entries.is_empty() or String(container_id).is_empty():
        return {}
    var total_weight: int = 0
    for entry: LootEntryDefinition in entries:
        if entry == null or entry.item == null or entry.weight < 1 or entry.min_amount < 1:
            return {}
        if entry.max_amount < entry.min_amount:
            return {}
        total_weight += entry.weight
    var random := RandomNumberGenerator.new()
    random.seed = world_seed ^ int(String(table_id).hash()) ^ int(String(container_id).hash())
    var items: Dictionary = {}
    for attempt: int in range(draws):
        var draw: int = random.randi_range(1, total_weight)
        for entry: LootEntryDefinition in entries:
            draw -= entry.weight
            if draw <= 0:
                var key: String = String(entry.item.item_id)
                items[key] = int(items.get(key, 0)) + random.randi_range(entry.min_amount, entry.max_amount)
                break
    return items
