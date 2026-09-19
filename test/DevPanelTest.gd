extends GdUnitTestSuite

## The dev panel's state edits (ui/DevPanel.gd). The panel itself is only keys and
## rows; what matters is that a row lands the game in the state it says it does, so
## these drive the rows directly rather than through the keyboard.

var _gs: GameState
var _panel: DevPanel
var _radio_persisted := true


func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	_gs.set_process(false)
	add_child(_gs)
	# Naming a Gate radios the player, and the real radio would write its show-once
	# flags to the player's own save. Hold it off for the length of the test.
	_radio_persisted = RobotRadio.persist
	RobotRadio.persist = false


func after_test() -> void:
	RobotRadio.silence()
	RobotRadio.persist = _radio_persisted
	InventoryManager.clear_inventory()


## The panel, built after whatever world the test wants it to read.
func _panel_in_tree() -> DevPanel:
	_panel = auto_free(DevPanel.new()) as DevPanel
	add_child(_panel)
	return _panel


func _planet(planet_name: String, type := Planet.PlanetType.ROCKY) -> Planet:
	var planet := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	planet.name = planet_name
	planet.radius = 400.0
	planet.planet_type = type
	planet.enable_orbiting = false
	add_child(planet)
	for grown in planet.get_ore_deposits():
		grown.free()
	return planet


func _gate(planet: Planet, core := false) -> Gate:
	var gate := auto_free(load("res://entities/structures/Gate.tscn").instantiate()) as Gate
	gate.is_core = core
	gate.enable_orbiting = false
	gate.persist = false  # keep identification out of the player's save
	planet.add_child(gate)
	return gate


## Run the row named `label` in `section` with `direction` (-1 / +1, or 0 for ENTER).
func _run(section: String, label: String, direction: int) -> void:
	for i in _panel._sections.size():
		if _panel._sections[i]["name"] != section:
			continue
		for row in _panel._sections[i]["build"].call():
			if row["label"] == label:
				row["act"].call(direction)
				return
	fail("no row '%s' in section '%s'" % [label, section])


func _read(section: String, label: String) -> String:
	for i in _panel._sections.size():
		if _panel._sections[i]["name"] != section:
			continue
		for row in _panel._sections[i]["build"].call():
			if row["label"] == label:
				return str(row["value"].call())
	return ""


# --- Modules -----------------------------------------------------------------

## The count maps onto Gates in save-key order, so the same number always brings the
## same Modules online, and the Core's Gate is never one of them.
func test_modules_online_powers_gates_in_order() -> void:
	_gate(_planet("Veld"))
	_gate(_planet("Crom"))
	_gate(_planet("Sun", Planet.PlanetType.SUN), true)
	_panel_in_tree()

	_run("PROGRESS", "MODULES ONLINE", 1)
	assert_int(_gs.titan_influence()).is_equal(1)
	assert_bool(_gs.is_gate_powered("Crom")).is_true()  # sorts before Veld

	_run("PROGRESS", "MODULES ONLINE", 1)
	assert_int(_gs.titan_influence()).is_equal(2)
	assert_bool(_gs.is_gate_powered("Veld")).is_true()
	assert_bool(_gs.is_gate_powered("Sun")).is_false()

	_run("PROGRESS", "MODULES ONLINE", -1)
	assert_int(_gs.titan_influence()).is_equal(1)
	assert_bool(_gs.is_gate_powered("Veld")).is_false()


## ENTER tops the row out, so the last Module's worth of Titan influence can be
## looked at without five Gates to fly to. The Core's Gate is still not a Module.
func test_enter_brings_every_module_online() -> void:
	for planet_name in ["TERRA-0", "Roke", "Sonder", "Crom", "Veld"]:
		_gate(_planet(planet_name))
	_gate(_planet("Sun", Planet.PlanetType.SUN), true)
	_panel_in_tree()
	_run("PROGRESS", "MODULES ONLINE", 0)
	assert_int(_gs.titan_influence()).is_equal(Gate.MODULE_COUNT)
	assert_bool(_gs.is_gate_powered("Sun")).is_false()


func test_modules_row_never_goes_below_zero() -> void:
	_gate(_planet("Veld"))
	_panel_in_tree()
	_run("PROGRESS", "MODULES ONLINE", -1)
	assert_int(_gs.titan_influence()).is_equal(0)


# --- Gates and planets -------------------------------------------------------

## Naming is all-or-nothing, and the Core's Gate is named along with the rest.
func test_naming_gates_covers_the_core_too() -> void:
	_gate(_planet("Veld"))
	_gate(_planet("Sun", Planet.PlanetType.SUN), true)
	_panel_in_tree()

	_run("PROGRESS", "GATES NAMED", 0)
	assert_int(_gs.identified_gates.size()).is_equal(2)
	assert_str(_read("PROGRESS", "GATES NAMED")).is_equal("2 / 2")

	_run("PROGRESS", "GATES NAMED", -1)
	assert_int(_gs.identified_gates.size()).is_equal(0)


## The sun is never scanned, so it isn't one of the planets this row counts.
func test_scanning_skips_the_sun() -> void:
	_planet("Veld")
	_planet("Crom")
	_planet("Sun", Planet.PlanetType.SUN)
	_panel_in_tree()

	_run("PROGRESS", "PLANETS SCANNED", 0)
	assert_int(_gs.scanned_planets.size()).is_equal(2)
	assert_bool(_gs.is_planet_scanned("Sun")).is_false()
	assert_str(_read("PROGRESS", "PLANETS SCANNED")).is_equal("2 / 2")

	_run("PROGRESS", "PLANETS SCANNED", -1)
	assert_int(_gs.scanned_planets.size()).is_equal(0)


func test_refill_ore_seams_clears_every_regrow_timer() -> void:
	_gs.spend_ore("Veld:0", 120.0)
	_panel_in_tree()
	_run("PROGRESS", "REFILL ORE SEAMS", 0)
	assert_float(_gs.ore_regrow_left("Veld:0")).is_equal(0.0)


func test_death_count_steps_and_floors_at_zero() -> void:
	_panel_in_tree()
	_run("PROGRESS", "DEATHS", 1)
	_run("PROGRESS", "DEATHS", 1)
	assert_int(_gs.death_count).is_equal(2)
	_run("PROGRESS", "DEATHS", -1)
	_run("PROGRESS", "DEATHS", -1)
	_run("PROGRESS", "DEATHS", -1)
	assert_int(_gs.death_count).is_equal(0)


# --- Upgrades ----------------------------------------------------------------

## Stepping a track sets its tier; ENTER fits the top one. With no ship in the tree
## nothing is refitted, but the levels are still what a store purchase would leave.
func test_upgrade_track_steps_and_tops_out() -> void:
	_panel_in_tree()
	_run("UPGRADES", "HULL PLATING", 1)
	assert_int(_gs.get_upgrade_level("hull")).is_equal(1)
	_run("UPGRADES", "HULL PLATING", 0)
	assert_int(_gs.get_upgrade_level("hull")).is_equal(3)
	_run("UPGRADES", "HULL PLATING", -1)
	assert_int(_gs.get_upgrade_level("hull")).is_equal(2)
	assert_str(_read("UPGRADES", "HULL PLATING")).is_equal("TIER 2 / 3")


## The scanner's unlock flag is set by refitting the track, and stepping the track
## back clears it again — a tier that came off must not leave the tool behind.
func test_scanner_track_sets_and_clears_its_unlock() -> void:
	# Refitting reads the upgrade table off the stores in the tree.
	var store := auto_free(Store.new()) as Store
	store.store_data = load("res://entities/Store/SR7Store.tres") as StoreData
	add_child(store)
	var ship := auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	add_child(ship)
	_panel_in_tree()

	_run("UPGRADES", "PLANET SCANNER", 1)
	assert_bool(_gs.has_planet_scanner).is_true()
	_run("UPGRADES", "PLANET SCANNER", -1)
	assert_bool(_gs.has_planet_scanner).is_false()


## The drone bay has no upgrade to buy, so its flag is the row itself, and a
## refitted track must not knock it back off.
func test_drone_bay_flag_survives_an_upgrade_refit() -> void:
	_panel_in_tree()
	_run("UPGRADES", "DRONE BAY", 1)
	assert_bool(_gs.has_drone_bay).is_true()
	_run("UPGRADES", "HULL PLATING", 1)
	assert_bool(_gs.has_drone_bay).is_true()
	_run("UPGRADES", "DRONE BAY", -1)
	assert_bool(_gs.has_drone_bay).is_false()


# --- Ship --------------------------------------------------------------------

func test_hold_row_fills_to_capacity_and_dumps() -> void:
	var ship := auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	ship.add_to_group("ship")
	add_child(ship)
	ship.max_cargo_weight = 20.0
	_panel_in_tree()

	_run("SHIP", "HOLD", 1)
	assert_float(InventoryManager.get_total_weight()).is_equal(20.0)
	assert_str(_read("SHIP", "HOLD")).is_equal("20 / 20")

	# A second fill has no room left to use, and must not overfill.
	_run("SHIP", "HOLD", 1)
	assert_float(InventoryManager.get_total_weight()).is_equal(20.0)

	_run("SHIP", "HOLD", -1)
	assert_float(InventoryManager.get_total_weight()).is_equal(0.0)


func test_no_damage_flag_stops_the_hull_taking_hits() -> void:
	var ship := auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	ship.add_to_group("ship")
	add_child(ship)
	_panel_in_tree()

	_run("SHIP", "NO DAMAGE", 1)
	ship.take_damage(500.0)
	assert_float(ship.hull_strength).is_equal(ship.max_hull)

	_run("SHIP", "NO DAMAGE", -1)
	ship.take_damage(10.0)
	assert_float(ship.hull_strength).is_less(ship.max_hull)


func test_infinite_fuel_flag_leaves_the_tank_alone() -> void:
	var ship := auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	ship.add_to_group("ship")
	add_child(ship)
	_panel_in_tree()

	_run("SHIP", "INFINITE FUEL", 1)
	var before := ship.fuel
	assert_bool(ship.consume_fuel(50.0)).is_true()  # the engine still fires
	assert_float(ship.fuel).is_equal(before)

	_run("SHIP", "INFINITE FUEL", -1)
	ship.consume_fuel(50.0)
	assert_float(ship.fuel).is_equal(before - 50.0)


func test_credits_row_steps_and_floors_at_zero() -> void:
	var ship := auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	ship.add_to_group("ship")
	add_child(ship)
	_panel_in_tree()

	_run("SHIP", "CREDITS", 0)
	assert_int(_gs.credits).is_equal(DevPanel.CREDIT_JUMP)
	_run("SHIP", "CREDITS", -1)
	assert_int(_gs.credits).is_equal(DevPanel.CREDIT_JUMP - DevPanel.CREDIT_STEP)

	_gs.credits = 10
	_run("SHIP", "CREDITS", -1)
	assert_int(_gs.credits).is_equal(0)


# --- Guards ------------------------------------------------------------------

## No ship in the tree (the start menu, a respawn in flight): the ship and warp
## sections come back empty instead of reaching through a null.
func test_sections_are_empty_without_a_ship() -> void:
	_panel_in_tree()
	assert_array(_panel._ship_rows()).is_empty()
	assert_array(_panel._warp_rows()).is_empty()


## It only opens during play, so it can't pause over the start menu.
func test_will_not_open_without_a_running_game() -> void:
	_panel_in_tree()
	assert_bool(_panel.can_open()).is_false()
