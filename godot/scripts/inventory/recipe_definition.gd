class_name RecipeDefinition
extends Resource
## Ingredients use stable item IDs; outputs reference an authored item Resource.

@export var recipe_id: StringName
@export var ingredients: Dictionary = {}
@export var output_item: ItemDefinition
@export_range(1, 24) var output_quantity: int = 1
