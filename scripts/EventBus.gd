extends Node

## Global event bus for decoupled communication between systems.
## ScrapNodes register their harvest state here, and HUD listens for changes.

signal harvest_available_changed(can_harvest: bool)
## Emitted when any ScrapNode becomes harvestable or unharvestable.
## True if at least one ScrapNode can be harvested, false otherwise.

signal action_message_changed(message: String)
## Emitted when an action message should be displayed or cleared.
## Empty string clears/hides the message. Components provide full formatted messages.

signal ship_respawned()
## Emitted when the ship respawns after game over or reset.

signal planets_restored()
## Emitted when planet orbital angles have been restored from save file.

signal game_unpaused(pause_duration: float)
## Emitted when game resumes from pause with the duration paused in seconds.

var _harvestable_nodes: Dictionary = {}  # Track ScrapNodes that can be harvested
var _registered_nodes: Dictionary = {}  # Track registered ScrapNodes and their callables

func register_resource_node(resource_node: ScrapNode) -> void:
	if not resource_node:
		return

	if _registered_nodes.has(resource_node):
		return

	var callable = func(can_harvest: bool):
		_on_resource_can_harvest_changed(resource_node, can_harvest)

	resource_node.can_harvest_changed.connect(callable)

	_registered_nodes[resource_node] = callable

	_cleanup_invalid_nodes()

func unregister_resource_node(resource_node: ScrapNode) -> void:
	if not resource_node:
		return

	if _registered_nodes.has(resource_node):
		var callable = _registered_nodes[resource_node]
		if resource_node.can_harvest_changed.is_connected(callable):
			resource_node.can_harvest_changed.disconnect(callable)

	_registered_nodes.erase(resource_node)
	_harvestable_nodes.erase(resource_node)
	_check_harvest_state()

func _on_resource_can_harvest_changed(resource_node: ScrapNode, can_harvest: bool) -> void:
	if can_harvest:
		_harvestable_nodes[resource_node] = true
	else:
		_harvestable_nodes.erase(resource_node)

	_check_harvest_state()


func _check_harvest_state() -> void:
	_cleanup_invalid_nodes()
	var can_harvest = not _harvestable_nodes.is_empty()
	harvest_available_changed.emit(can_harvest)

	if can_harvest:
		var action_key = InputUtils.get_action_key_name("action")
		action_message_changed.emit('Press "%s" to harvest' % [action_key])
	else:
		action_message_changed.emit("")

func _cleanup_invalid_nodes() -> void:
	for node in _harvestable_nodes.keys():
		if not is_instance_valid(node):
			_harvestable_nodes.erase(node)

	for node in _registered_nodes.keys():
		if not is_instance_valid(node):
			_registered_nodes.erase(node)

func is_harvest_available() -> bool:
	_cleanup_invalid_nodes()
	return not _harvestable_nodes.is_empty()
