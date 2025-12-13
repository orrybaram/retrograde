extends Node
class_name Save

static func save(gs, ship: Ship) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "credits", gs.credits)
	if ship:
		cfg.set_value("stats", "fuel", ship.fuel)
		cfg.set_value("stats", "max_fuel", ship.max_fuel)
		cfg.set_value("stats", "hull_strength", ship.hull_strength)
		cfg.set_value("stats", "max_hull", ship.max_hull)
	# Save inventory from InventoryManager
	var inventory = InventoryManager.get_inventory_dict()
	for k in inventory.keys():
		cfg.set_value("cargo", k, inventory[k])
	cfg.save("user://save.cfg")

static func load_into(gs, ship: Ship) -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://save.cfg") != OK:
		return
	gs.credits = int(cfg.get_value("stats", "credits", 0))
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
