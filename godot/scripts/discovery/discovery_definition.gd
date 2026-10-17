class_name DiscoveryDefinition
extends Resource
## Authored world observations, not tasks or omniscient quest objectives.

@export var discovery_id: StringName
@export var title: String
@export_multiline var observation: String
@export_multiline var hypothesis: String
@export_multiline var personal_plan: String
@export var bark_event: StringName
