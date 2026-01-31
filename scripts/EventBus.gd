extends Node

## Global event bus for decoupled communication between systems.
## ResourceNodes register their harvest state here, and HUD listens for changes.

signal harvest_available_changed(can_harvest: bool)
## Emitted when any ResourceNode becomes harvestable or unharvestable.
## True if at least one ResourceNode can be harvested, false otherwise.

signal action_message_changed(message: String)
## Emitted when an action message should be displayed or cleared.
## Empty string clears/hides the message. Components provide full formatted messages.

signal ship_respawned()
## Emitted when the ship respawns after game over or reset.

signal planets_restored()
## Emitted when planet orbital angles have been restored from save file.

signal spawner_finished(spawner_key: String)
## Emitted when a resource spawner finishes spawning all its resources.

signal all_spawners_finished()
## Emitted when all registered spawners have finished spawning.

signal game_unpaused(pause_duration: float)
## Emitted when game resumes from pause with the duration paused in seconds.

var _harvestable_nodes: Dictionary = {}  # Track ResourceNodes that can be harvested
var _pending_spawners: Dictionary = {}  # Track spawners that are still spawning
var _registered_nodes: Dictionary = {}  # Track registered ResourceNodes and their callables

func register_resource_node(resource_node: ResourceNode) -> void:
	# Register a ResourceNode to track its harvest state.
	if not resource_node:
		return
	
	# Skip if already registered (avoid duplicate connections)
	if _registered_nodes.has(resource_node):
		return
	
	# Use a lambda to capture the resource_node reference
	# The signal emits (can_harvest: bool), so we need to wrap it
	var callable = func(can_harvest: bool):
		_on_resource_can_harvest_changed(resource_node, can_harvest)
	
	# Connect to the resource node's signal
	resource_node.can_harvest_changed.connect(callable)
	
	# Store the callable so we can disconnect it later
	_registered_nodes[resource_node] = callable
	
	# Clean up invalid nodes
	_cleanup_invalid_nodes()

func unregister_resource_node(resource_node: ResourceNode) -> void:
	# Unregister a ResourceNode when it's being destroyed.
	if not resource_node:
		return
	
	# Disconnect the signal using the stored callable
	if _registered_nodes.has(resource_node):
		var callable = _registered_nodes[resource_node]
		if resource_node.can_harvest_changed.is_connected(callable):
			resource_node.can_harvest_changed.disconnect(callable)
	
	_registered_nodes.erase(resource_node)
	_harvestable_nodes.erase(resource_node)
	_check_harvest_state()

func _on_resource_can_harvest_changed(resource_node: ResourceNode, can_harvest: bool) -> void:
	# Called when a ResourceNode's harvest state changes.
	if can_harvest:
		_harvestable_nodes[resource_node] = true
	else:
		_harvestable_nodes.erase(resource_node)
	
	_check_harvest_state()


func _check_harvest_state() -> void:
	# Check if any ResourceNode can be harvested and emit signal if state changed.
	_cleanup_invalid_nodes()
	var can_harvest = not _harvestable_nodes.is_empty()
	harvest_available_changed.emit(can_harvest)
	
	# Also emit action message for harvest
	if can_harvest:
		var action_key = InputUtils.get_action_key_name("action")
		action_message_changed.emit('Press "%s" to harvest' % [action_key])
	else:
		action_message_changed.emit("")

func _cleanup_invalid_nodes() -> void:
	# Remove invalid ResourceNodes from tracking.
	for node in _harvestable_nodes.keys():
		if not is_instance_valid(node):
			_harvestable_nodes.erase(node)
	
	for node in _registered_nodes.keys():
		if not is_instance_valid(node):
			_registered_nodes.erase(node)

func is_harvest_available() -> bool:
	# Check if any ResourceNode can currently be harvested.
	_cleanup_invalid_nodes()
	return not _harvestable_nodes.is_empty()

## Register a spawner as pending (still spawning)
func register_pending_spawner(spawner_key: String) -> void:
	_pending_spawners[spawner_key] = true

## Mark a spawner as finished and emit signals
func mark_spawner_finished(spawner_key: String) -> void:
	_pending_spawners.erase(spawner_key)
	spawner_finished.emit(spawner_key)

	if _pending_spawners.is_empty():
		all_spawners_finished.emit()

## Check if all spawners have finished
func are_all_spawners_finished() -> bool:
	return _pending_spawners.is_empty()

## Reset spawner tracking (call before starting game)
func reset_spawner_tracking() -> void:
	_pending_spawners.clear()
