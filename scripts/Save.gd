extends Node
class_name Save

static func save(gs) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "credits", gs.credits)
	cfg.set_value("stats", "fuel", gs.fuel)
	for k in gs.cargo.keys():
		cfg.set_value("cargo", k, gs.cargo[k])
	cfg.save("user://save.cfg")

static func load_into(gs) -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://save.cfg") != OK:
		return
	gs.credits = int(cfg.get_value("stats", "credits", 0))
	gs.fuel = float(cfg.get_value("stats", "fuel", 100.0))
	for k in gs.cargo.keys():
		gs.cargo[k] = int(cfg.get_value("cargo", k, 0))
