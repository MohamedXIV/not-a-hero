class_name LootEntryDefinition
extends Resource
## One weighted item kind; authored in inspector as part of a region LootTable.

@export var item: ItemDefinition
@export_range(1, 100) var weight: int = 1
@export_range(1, 10) var min_amount: int = 1
@export_range(1, 10) var max_amount: int = 2
