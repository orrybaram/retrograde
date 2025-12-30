extends Node
class_name Save

const LandedState = preload("res://entities/Ship/states/LandedState.gd")

static func save(gs: GameState, ship: Ship) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "credits", gs.credits)
	cfg.set_value("stats", "death_count", gs.death_count)
	if ship:
		cfg.set_value("stats", "fuel", ship.fuel)
		cfg.set_value("stats", "max_fuel", ship.max_fuel)
		cfg.set_value("stats", "hull_strength", ship.hull_strength)
		cfg.set_value("stats", "max_hull", ship.max_hull)
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
	
	cfg.save("user://save.cfg")

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
	if cfg.load("user://save.cfg") != OK:
		return
	
	gs.credits = int(cfg.get_value("stats", "credits", 0))
	gs.death_count = int(cfg.get_value("stats", "death_count", 0))
	if ship:
		ship.fuel = float(cfg.get_value("stats", "fuel", 100.0))
		ship.max_fuel = float(cfg.get_value("stats", "max_fuel", 100.0))
		ship.hull_strength = float(cfg.get_value("stats", "hull_strength", 100.0))
		ship.max_hull = float(cfg.get_value("stats", "max_hull", 100.0))
	
	# Load inventory into InventoryManager
	var inventory_dict: Dictionary = {}
	var cargo_section = cfg.get_section_keys("cargo")
	if cargo_section:
		for k in cargo_section:
			var value = int(cfg.get_value("cargo", k, 0))
			# Backward compatibility: convert old "Scrap" to "scrap"
			var item_id = k.to_lower() if k == "Scrap" else k
			# Merge quantities if both old and new keys exist
			if inventory_dict.has(item_id):
				inventory_dict[item_id] += value
			else:
				inventory_dict[item_id] = value
	InventoryManager.set_inventory_dict(inventory_dict)
	
	# Load upgrades
	var upgrades_section = cfg.get_section_keys("upgrades")
	if upgrades_section:
		for upgrade_path in upgrades_section:
			var level = int(cfg.get_value("upgrades", upgrade_path, 0))
			gs.set_upgrade_level(upgrade_path, level)

## Load planet orbital angles into a dictionary
## Returns a dictionary mapping planet keys to orbital angles
## This should be called after planets are generated
static func load_planet_angles() -> Dictionary:
	var planet_angles: Dictionary = {}
	var cfg := ConfigFile.new()
	if cfg.load("user://save.cfg") != OK:
		return planet_angles
	
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
	if cfg.load("user://save.cfg") != OK:
		return Vector2.ZERO
	
	var x = float(cfg.get_value("stats", "spawn_position_x", 0.0))
	var y = float(cfg.get_value("stats", "spawn_position_y", 0.0))
	return Vector2(x, y)

## Load spawn rotation from save file
## Returns 0.0 if no save file or no rotation saved
static func load_spawn_rotation() -> float:
	var cfg := ConfigFile.new()
	if cfg.load("user://save.cfg") != OK:
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
	if cfg.load("user://save.cfg") != OK:
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
	return cfg.load("user://save.cfg") == OK

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
