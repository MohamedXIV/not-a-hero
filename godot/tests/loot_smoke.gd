extends SceneTree
## Loot probabilities differ by authored region; no geometry/random key changes.

const ASH: LootTableDefinition = preload("res://resources/world/loot/ash_table.tres")
const CABLE: LootTableDefinition = preload("res://resources/world/loot/cable_table.tres")
const RELAY: LootTableDefinition = preload("res://resources/world/loot/relay_table.tres")
const COOLANT: LootTableDefinition = preload("res://resources/world/loot/coolant_table.tres")


func _initialize() -> void:
    call_deferred("_check")


func _check() -> void:
    var key: StringName = &"world/ash_flats/salvage_02"
    var rolled: Dictionary = ASH.roll(1573, key)
    assert(not rolled.is_empty(), "Authored cache should contain loot")
    assert(rolled == ASH.roll(1573, key), "Same seed and container ID must reproduce identical items")
    for item_id: Variant in rolled.keys():
        assert(item_id in ["scrap", "wire"], "Ash biome must not generate other biomes' items")
        assert(int(rolled[item_id]) > 0, "No zero or negative loot")
    for item_id: Variant in CABLE.roll(1573, &"world/cable_forest/cache_01").keys():
        assert(item_id in ["wire", "capacitor", "scrap"], "Cable table item mismatch")
    for item_id: Variant in RELAY.roll(1573, &"world/relay_waste/alloy_cache_01").keys():
        assert(item_id in ["alloy", "scrap"], "Relay table item mismatch")
    var basin_id: StringName = &"world/coolant_basin/filter_cache_01"
    var basin_loot: Dictionary = COOLANT.roll(1573, basin_id)
    assert(basin_loot == COOLANT.roll(1573, basin_id), "Coolant salvage must be seed-stable")
    for item_id: Variant in basin_loot.keys():
        assert(item_id in ["coolant_filter", "capacitor", "alloy"], "Coolant biome items mismatch")
    var outcomes: Dictionary = {}
    for seed: int in range(120):
        var result: Dictionary = ASH.roll(seed, key)
        outcomes[JSON.stringify(result)] = true
    assert(outcomes.size() > 2, "Different seeds should vary the salvage outcomes")
    print("PASS: authored regional seeded loot, reproducible IDs and cross-seed variation")
    quit(0)
