extends GdUnitTestSuite

## There is no store, no upgrade and no planetary scan (docs/adr/0007, docs/OPENING.md §9).
## SR-7's dock offers nothing to buy, the ship's limits are fixed, and an old save's
## bought upgrades and planetary scans are left behind when it loads.

const SAVE_FILE := "user://no_store_test_save.cfg"

var _gs: GameState
var _was_active: bool
var _was_file: String

func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	add_child(_gs)
	# Point Save at a scratch file rather than the player's own save.
	_was_active = Playtest.active
	_was_file = Playtest._save_file
	Playtest.active = true
	Playtest._save_file = SAVE_FILE

func after_test() -> void:
	Playtest.active = _was_active
	Playtest._save_file = _was_file
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))


func test_the_dock_menu_offers_nothing_to_buy() -> void:
	var dialogue := auto_free(load("res://ui/SpacePortDialogue.tscn").instantiate()) as SpacePortDialogue
	add_child(dialogue)
	dialogue.open_dialogue(null)
	var labels := dialogue._menu_items.map(func(item: Dictionary) -> String: return item["label"])
	assert_array(labels).contains_exactly(["DEPART"])


func test_sr7s_port_carries_no_store() -> void:
	var port := auto_free(load("res://entities/structures/SpacePort.tscn").instantiate()) as Node
	assert_object(port.get_node_or_null("Store")).is_null()


func test_an_old_saves_upgrades_do_not_raise_the_ships_limits() -> void:
	var ship := auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	add_child(ship)
	var hull := ship.max_hull
	var tank := ship.drive.max_fuel
	var hold := ship.max_cargo_weight
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "fuel", tank * 3.0)
	cfg.set_value("stats", "hull_strength", hull * 3.0)
	cfg.set_value("upgrades", "hull", 3)
	cfg.set_value("upgrades", "fuel_tank", 3)
	cfg.set_value("upgrades", "cargo", 3)
	cfg.set_value("upgrades", "planet_scanner", 1)
	cfg.save(SAVE_FILE)
	Save.load_into(_gs, ship)
	assert_float(ship.max_hull).is_equal(hull)
	assert_float(ship.drive.max_fuel).is_equal(tank)
	assert_float(ship.max_cargo_weight).is_equal(hold)
	assert_float(ship.drive.fuel).is_equal(tank)
	assert_float(ship.hull_strength).is_equal(hull)
	assert_bool("upgrade_levels" in _gs).is_false()
	assert_bool("has_planet_scanner" in _gs).is_false()


func test_an_old_saves_planetary_scans_are_left_behind() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scan", "planets", PackedStringArray(["Veld/Rook", "Crom"]))
	cfg.save(SAVE_FILE)
	_gs.mark_planet_scanned("Veld")
	Save.load_into(_gs, null)
	assert_bool(_gs.is_planet_scanned("Veld/Rook")).is_false()
	assert_bool(_gs.is_planet_scanned("Crom")).is_false()
	assert_bool(_gs.is_planet_scanned("Veld")).is_false()


func test_a_save_writes_no_upgrades_or_scans() -> void:
	_gs.mark_planet_scanned("Crom")
	Save.save(_gs, null)
	var cfg := ConfigFile.new()
	assert_int(cfg.load(SAVE_FILE)).is_equal(OK)
	assert_bool(cfg.has_section("upgrades")).is_false()
	assert_bool(cfg.has_section("scan")).is_false()


func test_the_ship_has_no_planetary_scanner() -> void:
	var ship := auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	add_child(ship)
	assert_object(ship.get_node_or_null("PlanetScanner")).is_null()
	assert_object(ship.get_node_or_null("PlanetLog")).is_not_null()
