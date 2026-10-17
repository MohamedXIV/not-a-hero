extends SceneTree
## Pure transactional inventory/recipe checks, no scene or player save required.

const RECIPE: RecipeDefinition = preload("res://resources/recipes/relay_fuse.tres")


func _initialize() -> void:
    call_deferred("_check")


func _check() -> void:
    var bag := InventoryState.new()
    assert(not bag.try_craft(RECIPE), "Can't craft missing ingredients")
    assert(bag.snapshot().is_empty(), "Failed crafting may not mutate inventory")
    assert(bag.try_receive({"scrap": 3, "wire": 1}), "Accept initial salvage")
    assert(not bag.try_receive({"scrap": 99}), "Capacity exceeded transaction must fail")
    assert(bag.quantity(&"scrap") == 3, "Failed add mutated current items")
    assert(bag.try_craft(RECIPE), "Craft a real relay fuse")
    assert(bag.quantity(&"scrap") == 0 and bag.quantity(&"wire") == 0, "Recipe consumes exact costs")
    assert(bag.quantity(&"relay_fuse") == 1, "Recipe produces exactly one fuse")
    assert(not bag.try_craft(RECIPE), "Can't duplicate items via repeated craft")
    var snapshot: Dictionary = bag.snapshot()
    assert(bag.restore_snapshot({"scrap": 3.0}), "JSON floats that represent whole integers are valid")
    assert(bag.quantity(&"scrap") == 3, "Restored quantities normalize to integers")
    assert(not bag.restore_snapshot({"scrap": 2.5}), "Fractional JSON quantities rejected")
    assert(bag.restore_snapshot(snapshot), "Original snapshot restores")
    assert(not bag.restore_snapshot({"scrap": -1}), "Malformed inventory rejected")
    assert(bag.snapshot() == snapshot, "Failed restore may not mutate items")
    print("PASS: atomic inventory transactions, ingredient checks and recipe output")
    quit(0)
