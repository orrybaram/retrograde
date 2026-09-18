extends Node
class_name Save

## Static save/load helpers using ConfigFile (user://save.cfg).
## Serializes GameState (credits, upgrades, death count), Ship stats (fuel, hull, cargo),
## InventoryManager contents, planet orbital angles, scanned planets, dug-out ore seams
## (seconds until they refill), and which radio tips were seen.

const RADIO_SECTION := "radio"
const RADIO_SEEN_KEY := "seen"
const SCAN_SECTION := "scan"
const SCAN_PLANETS_KEY := "planets"
const ORE_SECTION := "ore"
const ORE_REGROW_KEY := "regrow"

static func save(gs: GameState, ship: Ship) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "credits", gs.credits)
	cfg.set_value("stats", "death_count", gs.death_count)
	if ship:
		cfg.set_value("stats", "fuel", ship.fuel)
		cfg.set_value("stats", "max_fuel", ship.max_fuel)
		cfg.set_value("stats", "hull_strength", ship.hull_strength)
		cfg.set_value("stats", "max_hull", ship.max_hull)
		cfg.set_value("stats", "max_cargo_weight", ship.max_cargo_weight)
		# Save spawn position and rotation (for docked state)
		cfg.set_value("stats", "spawn_position_x", ship.global_position.x)
		cfg.set_value("stats", "spawn_position_y", ship.global_position.y)
		cfg.set_value("stats", "spawn_rotation", ship.rotation)
		
		# Save dockable identifier if ship is docked
		var dockable_key = _get_dockable_key_from_ship(ship)
		if dockable_key != "":
			cfg.set_value("stats", "docked_at", dockable_key)
		else:
			cfg.set_value("stats", "docked_at", "")
	
	# Save inventory from InventoryManager
	var inventory = InventoryManager.get_inventory_dict()
	for k in inventory.keys():
		cfg.set_value("cargo", k, inventory[k])
	
	# Gems left floating at wrecks, and abandoned ships
	cfg.set_value("wreck", "gems", Gem.wreck_rows())
	if ship and ship.is_inside_tree():
		cfg.set_value("wreck", "derelicts", DerelictShip.snapshot_all(ship.get_tree()))

	# Save upgrades
	for upgrade_path in gs.upgrade_levels.keys():
		var level = gs.upgrade_levels[upgrade_path]
		cfg.set_value("upgrades", upgrade_path, level)
	
	# Save planet orbital angles
	if ship:
		var tree = ship.get_tree()
		if tree:
			var planets = tree.get_nodes_in_group("planets")
			for planet_node in planets:
				if planet_node is Planet:
					var planet = planet_node as Planet
					var planet_key = _get_planet_key(planet)
					if planet_key != "":
						cfg.set_value("planets", planet_key, planet.orbital_angle)

	cfg.set_value(RADIO_SECTION, RADIO_SEEN_KEY, RobotRadio.seen_ids())
	cfg.set_value(SCAN_SECTION, SCAN_PLANETS_KEY, PackedStringArray(gs.scanned_planets.keys()))
	cfg.set_value(ORE_SECTION, ORE_REGROW_KEY, gs.spent_ore.duplicate())

	cfg.save(Playtest.save_path())

## Writes only the radio show-once flags into an existing save, keeping the rest.
## With no save yet this does nothing (a flags-only file would enable CONTINUE);
## the next full save() writes them. `path` defaults to the game save.
static func save_radio_seen(ids: PackedStringArray, path: String = "") -> void:
	var file := path if path != "" else Playtest.save_path()
	var cfg := ConfigFile.new()
	if cfg.load(file) != OK:
		return
	cfg.set_value(RADIO_SECTION, RADIO_SEEN_KEY, ids)
	cfg.save(file)

static func load_radio_seen(path: String = "") -> PackedStringArray:
	var cfg := ConfigFile.new()
	if cfg.load(path if path != "" else Playtest.save_path()) != OK:
		return PackedStringArray()
	return PackedStringArray(cfg.get_value(RADIO_SECTION, RADIO_SEEN_KEY, PackedStringArray()))

## Writes only the scanned-planet keys into an existing save, keeping the rest, so a
## scan finished mid-flight is kept without saving the ship's position or hold.
## With no save yet this does nothing; the next full save() writes them.
static func save_scanned_planets(keys: PackedStringArray, path: String = "") -> void:
	var file := path if path != "" else Playtest.save_path()
	var cfg := ConfigFile.new()
	if cfg.load(file) != OK:
		return
	cfg.set_value(SCAN_SECTION, SCAN_PLANETS_KEY, keys)
	cfg.save(file)

static func load_scanned_planets(path: String = "") -> PackedStringArray:
	var cfg := ConfigFile.new()
	if cfg.load(path if path != "" else Playtest.save_path()) != OK:
		return PackedStringArray()
	return PackedStringArray(cfg.get_value(SCAN_SECTION, SCAN_PLANETS_KEY, PackedStringArray()))

## Writes only the spent-ore regrow timers into an existing save, like save_scanned_planets.
static func save_ore_regrowth(spent: Dictionary, path: String = "") -> void:
	var file := path if path != "" else Playtest.save_path()
	var cfg := ConfigFile.new()
	if cfg.load(file) != OK:
		return
	cfg.set_value(ORE_SECTION, ORE_REGROW_KEY, spent.duplicate())
	cfg.save(file)

## ore_id -> seconds until it refills.
static func load_ore_regrowth(path: String = "") -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path if path != "" else Playtest.save_path()) != OK:
		return {}
	var spent = cfg.get_value(ORE_SECTION, ORE_REGROW_KEY, {})
	var out := {}
	if spent is Dictionary:
		for ore_id in spent:
			out[str(ore_id)] = float(spent[ore_id])
	return out

## Helper function to get a unique key for a planet
## Uses planet name, and for moons includes parent name
static func _get_planet_key(planet: Planet) -> String:
	if not planet:
		return ""
	
	var planet_name = planet.name
	if planet_name == "":
		return ""
	
	# Check if this is a moon (has a parent planet)
	var parent = planet.get_parent()
	if parent is Planet:
		var parent_planet = parent as Planet
		var parent_name = parent_planet.name
		if parent_name != "":
			return parent_name + "/" + planet_name
	
	return planet_name

static func load_into(gs: GameState, ship: Ship) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(Playtest.save_path()) != OK:
		return
	
	gs.credits = int(cfg.get_value("stats", "credits", 0))
	gs.death_count = int(cfg.get_value("stats", "death_count", 0))
	RobotRadio.load_seen(load_radio_seen())
	gs.scanned_planets.clear()
	for key in load_scanned_planets():
		gs.mark_planet_scanned(key)
	gs.spent_ore = load_ore_regrowth()
	
	# Load inventory into InventoryManager (before reapply so cargo weight is correct)
	var inventory_dict: Dictionary = {}
	if cfg.has_section("cargo"):
		var cargo_section = cfg.get_section_keys("cargo")
		if cargo_section:
			for k in cargo_section:
				# Items from the retired tier system (scrap, salvage, ...) are dropped.
				if GemData.is_gem(k):
					inventory_dict[k] = int(cfg.get_value("cargo", k, 0))
	InventoryManager.set_inventory_dict(inventory_dict)

	# Load upgrades FIRST (from a clean slate, so a previous session's unlocks don't leak in)
	gs.upgrade_levels.clear()
	gs.has_drone_bay = false
	gs.has_planet_scanner = false
	if cfg.has_section("upgrades"):
		var upgrades_section = cfg.get_section_keys("upgrades")
		if upgrades_section:
			for upgrade_path in upgrades_section:
				var level = int(cfg.get_value("upgrades", upgrade_path, 0))
				gs.set_upgrade_level(upgrade_path, level)
	
	# Reapply all upgrades to ship based on loaded upgrade levels
	# This sets max_hull, max_fuel, max_cargo_weight correctly
	if ship and gs:
		ship.reapply_all_upgrades(gs)
	
	# Load current fuel and hull values AFTER reapplication (so they're clamped to max)
	if ship:
		ship.fuel = float(cfg.get_value("stats", "fuel", ship.max_fuel))
		ship.hull_strength = float(cfg.get_value("stats", "hull_strength", ship.max_hull))
		# Clamp to max values (in case save has invalid values)
		ship.fuel = min(ship.fuel, ship.max_fuel)
		ship.hull_strength = min(ship.hull_strength, ship.max_hull)
		ship.update_mass_from_cargo()  # Update mass based on loaded cargo

## Respawn saved wreck gems into `world`.
static func restore_wreck_gems(world: Node) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(Playtest.save_path()) != OK:
		return
	Gem.restore_wreck(world, cfg.get_value("wreck", "gems", []))

## Respawn saved abandoned ships into `world`, drawn with `hull`'s polygons.
static func restore_derelicts(world: Node, hull: Node2D) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(Playtest.save_path()) != OK:
		return
	DerelictShip.restore_all(world, hull, cfg.get_value("wreck", "derelicts", []))

## Load planet orbital angles into a dictionary
## Returns a dictionary mapping planet keys to orbital angles
## This should be called after planets are generated
static func load_planet_angles() -> Dictionary:
	var planet_angles: Dictionary = {}
	var cfg := ConfigFile.new()
	if cfg.load(Playtest.save_path()) != OK:
		return planet_angles

	if cfg.has_section("planets"):
		var planets_section = cfg.get_section_keys("planets")
		if planets_section:
			for planet_key in planets_section:
				var angle = float(cfg.get_value("planets", planet_key, 0.0))
				planet_angles[planet_key] = angle

	return planet_angles

## Load spawn position from save file
## Returns Vector2.ZERO if no save file or no spawn position saved
static func load_spawn_position() -> Vector2:
	var cfg := ConfigFile.new()
	if cfg.load(Playtest.save_path()) != OK:
		return Vector2.ZERO
	
	var x = float(cfg.get_value("stats", "spawn_position_x", 0.0))
	var y = float(cfg.get_value("stats", "spawn_position_y", 0.0))
	return Vector2(x, y)

## Load spawn rotation from save file
## Returns 0.0 if no save file or no rotation saved
static func load_spawn_rotation() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(Playtest.save_path()) != OK:
		return 0.0
	
	return float(cfg.get_value("stats", "spawn_rotation", 0.0))

## Get dockable key from ship's current state
## Returns empty string if ship is not docked
static func _get_dockable_key_from_ship(ship: Ship) -> String:
	if not ship:
		return ""
	
	# Check if ship is in LandedState
	var state_machine = ship.get_node_or_null("StateMachine") as StateMachine
	if not state_machine:
		return ""
	
	var current_state = state_machine.current_state
	if not current_state or not current_state is LandedState:
		return ""
	
	var landed_state = current_state as LandedState
	var locked_dockable = landed_state.locked_dockable
	if not locked_dockable or not is_instance_valid(locked_dockable):
		return ""
	
	return _get_dockable_key(locked_dockable)

## Get a unique key for a dockable entity
## Format: "PlanetName/SpacePort" or "PlanetName/SpaceStation/SpacePort" or "ParentPlanet/MoonName/SpacePort"
static func _get_dockable_key(dockable: Node2D) -> String:
	if not dockable or not is_instance_valid(dockable):
		return ""
	
	# Build path from dockable up to planet
	var path_parts: Array[String] = []
	var current: Node = dockable
	
	# Walk up the tree to find the planet, collecting node names
	while current:
		if current is Planet:
			# Found the planet - get its key (handles moons)
			var planet_key = _get_planet_key(current as Planet)
			if planet_key == "":
				return ""
			# Build full path: planet_key/path_to_dockable
			path_parts.reverse()
			return planet_key + "/" + "/".join(path_parts)
		else:
			# Add this node's name to path
			if current.name != "":
				path_parts.append(current.name)
		current = current.get_parent()
	
	return ""

## Load dockable key from save file
## Returns empty string if no save file or no dockable saved
static func load_dockable_key() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(Playtest.save_path()) != OK:
		return ""
	
	return str(cfg.get_value("stats", "docked_at", ""))

## Find a dockable entity by its key
## Returns the dockable Node2D if found, null otherwise
static func find_dockable_by_key(tree: SceneTree, dockable_key: String) -> Node2D:
	if dockable_key == "":
		return null
	
	# Split the key into parts
	var parts = dockable_key.split("/")
	if parts.size() < 2:
		return null
	
	# Find the planet (could be "PlanetName" or "ParentPlanet/MoonName")
	var planets = tree.get_nodes_in_group("planets")
	var planet: Planet = null
	
	# Try to match planet key (could be 1 or 2 parts for moons)
	for i in range(1, min(3, parts.size())):
		var potential_planet_key = "/".join(parts.slice(0, i))
		for planet_node in planets:
			if planet_node is Planet:
				var p = planet_node as Planet
				if _get_planet_key(p) == potential_planet_key:
					planet = p
					# Remaining parts are the path to dockable
					var dockable_path = parts.slice(i)
					return _find_dockable_in_node(planet, dockable_path)
	
	return null

## Helper to find dockable in a node's subtree following the path
static func _find_dockable_in_node(root: Node, path_parts: Array) -> Node2D:
	if path_parts.is_empty():
		# Check if root itself is dockable
		if root is Node2D and root.is_in_group("dockable"):
			return root as Node2D
		return null
	
	var current_part = path_parts[0]
	var remaining_parts = path_parts.slice(1)
	
	# Search children for matching name
	for child in root.get_children():
		if child.name == current_part:
			# Check if this is the dockable we're looking for
			if remaining_parts.is_empty():
				if child is Node2D and child.is_in_group("dockable"):
					return child as Node2D
			else:
				# Recurse into child
				var found = _find_dockable_in_node(child, remaining_parts)
				if found:
					return found
	
	return null

## Check if a save file exists
static func save_exists() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(Playtest.save_path()) == OK

## Restore planet orbital angles from saved data
## Should be called after planets are generated
static func restore_planet_angles(tree: SceneTree) -> void:
	var planet_angles = load_planet_angles()
	if planet_angles.is_empty():
		return

	var planets = tree.get_nodes_in_group("planets")
	for planet_node in planets:
		if planet_node is Planet:
			var planet = planet_node as Planet
			var planet_key = _get_planet_key(planet)
			if planet_key != "" and planet_angles.has(planet_key):
				planet.orbital_angle = planet_angles[planet_key]
