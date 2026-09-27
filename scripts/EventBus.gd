extends Node

## Global event bus for decoupled communication between systems.
## ScrapNodes register their harvest state here, and HUD listens for changes.

signal harvest_available_changed(can_harvest: bool)
## Emitted when any ScrapNode becomes harvestable or unharvestable.
## True if at least one ScrapNode can be harvested, false otherwise.

signal action_message_changed(message: String)
## Emitted when an action prompt should be displayed or cleared.
## Empty string clears it. IndicatorManager shows it next to what it's about.

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
## Scrap only: an ore seam is worked from the ground and has no in-range phase, so it
## never announces a beginning - its first hit is the first the bus hears of it.
## (Keep the ScrapNode type. EventBus is the second autoload and its
## `radio_message_requested` pulls RadioConversation -> RadioLine -> RobotRadio, which
## is autoload #8 and preloads the .tres conversations that RadioConversation itself
## scripts. Naming a gameplay class first resolves that graph before the cycle is
## reached; with every signal here typed as plain Node, the radio fails to load at boot.)

signal harvest_hit(node: Node, grade: HarvestTiming.Grade, gem_ids: Array[String], final: bool)
## Emitted when a timed release lands a hit and gems break off, on a ScrapNode or an
## OreDeposit alike. `final` is the hit that breaks the node open. EARLY releases are
## not hits and are not reported here.

signal sonar_pulsed(origin: Vector2)
## A sonar resonance ring left the ship at `origin` (global): one each time `action` is let
## go wherever the ship is free to act (held longer, it reaches further); puzzles listen here.

signal gem_collected(item_id: String, world_position: Vector2)
## Emitted when the ship picks up a loose gem (after it is added to the hold).

signal hold_cashed_in(credits: int)
## Emitted when docking at a port converts the hold into credits.

signal planet_scanned(planet: Planet)
## Emitted when the Planetary Scanner finishes mapping a planet (once per planet).

signal radio_message_requested(conversation: RadioConversation)
## Ask the guide robot to radio the player. RobotRadio queues it by priority.

signal section_seated(id: String)

## SR-7's core has caught (CoreHousing): the power comes up from it (StationPower).
signal core_started()
## A piece of SR-7 went home: a Section pulled into its Mount, or the hanging wing locked
## true. Fires once the clunk lands, with the Sections id.

signal ship_damaged(amount: float, hull_ratio: float)
## The hull actually lost HP — a hit the damage cooldown swallowed doesn't reach here.
## `amount` is the HP taken, `hull_ratio` what's left of the hull (0-1) after it.

signal ship_hull_changed(current: float, max_hull: float)
## The hull reading moved, for any reason: a hit, a repair, an upgrade, a respawn.

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
## (gems wait in space); the scrap callout says the hold is full.
func harvest_prompt() -> String:
	return action_prompt("HARVEST")

## "HARVEST" over "[SPACE]": what it does, then the bound action key on the line below.
## The prompt label centres each line, so the key sits under the middle of the word.
func action_prompt(verb: String) -> String:
	return key_prompt("action", verb)

## The same for any other action: "LIFT OFF" over "[UP]".
func key_prompt(action: String, verb: String) -> String:
	return "%s\n[%s]" % [verb, _key_label(action)]

## One line, for a terminal window's footer hint: "[SPACE] SKIP".
func inline_key_prompt(action: String, verb: String) -> String:
	return "[%s] %s" % [_key_label(action), verb]

## Several prompts side by side, each still word over key, centred in its own column.
## The prompt font is monospace, so padding with spaces lines the columns up.
func prompt_row(prompts: Array[String], gap := 3) -> String:
	var cols: Array = []
	var rows := 0
	for p in prompts:
		var lines := p.split("\n")
		var width := 0
		for line in lines:
			width = maxi(width, line.length())
		cols.append({"lines": lines, "width": width})
		rows = maxi(rows, lines.size())
	var out: PackedStringArray = []
	for r in rows:
		var cells: PackedStringArray = []
		for c in cols:
			var line: String = c["lines"][r] if r < c["lines"].size() else ""
			var pad: int = c["width"] - line.length()
			cells.append(" ".repeat(pad / 2) + line + " ".repeat(pad - pad / 2))
		out.append(" ".repeat(gap).join(cells))
	return "\n".join(out)

func _key_label(action: String) -> String:
	return Controls.label(action)

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
