extends Node
class_name Save

static func save(gs: GameState, ship: Ship) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "credits", gs.credits)
	cfg.set_value("stats", "death_count", gs.death_count)
	if ship:
		cfg.set_value("stats", "fuel", ship.fuel)
		cfg.set_value("stats", "max_fuel", ship.max_fuel)
		cfg.set_value("stats", "hull_strength", ship.hull_strength)
		cfg.set_value("stats", "max_hull", ship.max_hull)
		# Save spawn position
		cfg.set_value("stats", "spawn_position_x", ship.global_position.x)
		cfg.set_value("stats", "spawn_position_y", ship.global_position.y)
	
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
