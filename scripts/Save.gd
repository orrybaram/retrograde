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
	for k in gs.cargo.keys():
		cfg.set_value("cargo", k, gs.cargo[k])
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
	for k in gs.cargo.keys():
		gs.cargo[k] = int(cfg.get_value("cargo", k, 0))
