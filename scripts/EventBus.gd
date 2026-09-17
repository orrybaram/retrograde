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

signal resources_refresh_requested()
## Emitted when resource nodes should respawn (e.g. docking at a space port or respawning).

signal abandon_ship_requested()
## Emitted when a stranded (out of fuel) player acts: abandon ship, or a tractor-beam tow
## when a station is in range.

signal game_unpaused(pause_duration: float)
## Emitted when game resumes from pause with the duration paused in seconds.

signal harvest_began(scrap: ScrapNode)
## Emitted when the player starts (or resumes) holding the beam on a scrap node.

signal harvest_hit(scrap: ScrapNode, grade: HarvestTiming.Grade, gem_ids: Array[String], final: bool)
## Emitted when a timed release lands a hit and gems break off. `final` is the hit that
## destroys the scrap. EARLY releases are not hits and are not reported here.

signal gem_collected(item_id: String, world_position: Vector2)
## Emitted when the ship picks up a loose gem (after it is added to the hold).

signal hold_cashed_in(credits: int)
## Emitted when docking at a port converts the hold into credits.

signal radio_message_requested(conversation: RadioConversation)
## Ask the guide robot to radio the player. RobotRadio queues it by priority.

const CARGO_FULL_MESSAGE := "Hold full - dock at a port to cash in"

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

	action_message_changed.emit(harvest_prompt() if can_harvest else "")

## Prompt shown while scrap is harvestable. A full hold doesn't block harvesting
## (gems wait in space), but the prompt says so.
func harvest_prompt() -> String:
	var action_key = InputUtils.get_action_key_name("action")
	var prompt := 'Press "%s" to harvest' % [action_key]
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if ship and ship.is_cargo_full():
		return "%s - %s" % [prompt, CARGO_FULL_MESSAGE]
	return prompt

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
