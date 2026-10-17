class_name InventoryState
extends RefCounted
## Inventory changes are transactional: validate a proposed whole state first.
## No scene or UI dependencies. Unit-count capacity is deliberately small for P1.

const CAPACITY: int = 24

var _items: Dictionary = {}


func quantity(item_id: StringName) -> int:
    return int(_items.get(String(item_id), 0))


func snapshot() -> Dictionary:
    return _items.duplicate(true)


func restore_snapshot(raw: Dictionary) -> bool:
    if not _valid(raw):
        return false
    var normalized: Dictionary = {}
    for key: Variant in raw.keys():
        normalized[key] = int(raw[key])
    _items = normalized
    return true


func try_receive(additions: Dictionary) -> bool:
    var next: Dictionary = snapshot()
    for key: Variant in additions.keys():
        if typeof(key) != TYPE_STRING or typeof(additions[key]) != TYPE_INT or int(additions[key]) <= 0:
            return false
        next[key] = int(next.get(key, 0)) + int(additions[key])
    if not _valid(next):
        return false
    _items = next
    return true


func try_spend(item_id: StringName, amount: int) -> bool:
    if amount <= 0 or quantity(item_id) < amount:
        return false
    var next: Dictionary = snapshot()
    var key: String = String(item_id)
    if int(next[key]) == amount:
        next.erase(key)
    else:
        next[key] = int(next[key]) - amount
    _items = next
    return true


func try_craft(recipe: RecipeDefinition) -> bool:
    if recipe == null or recipe.output_item == null or recipe.output_quantity < 1:
        return false
    if recipe.ingredients.is_empty():
        return false
    var next: Dictionary = snapshot()
    for key: Variant in recipe.ingredients.keys():
        if typeof(key) != TYPE_STRING or typeof(recipe.ingredients[key]) != TYPE_INT:
            return false
        var required: int = int(recipe.ingredients[key])
        if required < 1 or int(next.get(key, 0)) < required:
            return false
        if int(next[key]) == required:
            next.erase(key)
        else:
            next[key] = int(next[key]) - required
    var output: String = String(recipe.output_item.item_id)
    next[output] = int(next.get(output, 0)) + recipe.output_quantity
    if not _valid(next):
        return false
    _items = next
    return true


func _valid(raw: Dictionary) -> bool:
    var total: int = 0
    for key: Variant in raw.keys():
        if typeof(key) != TYPE_STRING or String(key).is_empty():
            return false
        if typeof(raw[key]) != TYPE_INT and typeof(raw[key]) != TYPE_FLOAT:
            return false
        var count: int = int(raw[key])
        # JSON.parse_string creates floats for numeric JSON values, even "3".
        # Accept only exact integral quantities; never truncate a fractional value.
        if float(raw[key]) != float(count) or count <= 0 or count > 99:
            return false
        total += count
    return total <= CAPACITY
