extends GdUnitTestSuite

## Tests for the Sun Station and the Core's Gate: where they sit, why the Sun Station
## stays out of the home station's group, and the Core's Gate counting Modules instead
## of credits while doing nothing yet.

var _gs: GameState


func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	_gs.set_process(false)
	add_child(_gs)


# --- Placement ---------------------------------------------------------------

func _home_system() -> SceneState:
	return (load("res://scenes/HomeSystem.tscn") as PackedScene).get_state()


func _node_index(state: SceneState, path: String) -> int:
	for i in state.get_node_count():
		if str(state.get_node_path(i)) == path:
			return i
	return -1


func _override(state: SceneState, index: int, property: String) -> Variant:
	for i in state.get_node_property_count(index):
		if str(state.get_node_property_name(index, i)) == property:
			return state.get_node_property_value(index, i)
	return null


func test_the_sun_station_and_the_cores_gate_ride_the_same_orbit_at_the_sun() -> void:
	var state := _home_system()
	var station := _node_index(state, "./Sun/SunStation")
	var gate := _node_index(state, "./Sun/Gate")
	assert_int(station).is_greater(-1)
	assert_int(gate).is_greater(-1)
	assert_float(_override(state, station, "orbital_distance")).is_equal(20000.0)
	assert_float(_override(state, gate, "orbital_distance")).is_equal(20000.0)
	# Same angular rate, so the Gate stays beside the station rather than drifting off it
	assert_float(_override(state, gate, "orbital_speed")).is_equal(
		_override(state, station, "orbital_speed"))
	assert_float(_override(state, gate, "initial_angle_degrees")).is_not_equal(
		_override(state, station, "initial_angle_degrees"))


func test_the_cores_gate_is_marked_as_the_core_and_asks_for_no_credits() -> void:
	var state := _home_system()
	var gate := _node_index(state, "./Sun/Gate")
	assert_bool(_override(state, gate, "is_core")).is_true()
	assert_int(_override(state, gate, "power_cost")).is_equal(0)


## Every other Gate in the system belongs to a planet's Module.
func test_the_five_module_gates_are_left_alone() -> void:
	var state := _home_system()
	for planet in ["Veld", "Crom", "Sonder", "Roke", "TERRA-0"]:
		var gate := _node_index(state, "./Sun/%s/Gate" % planet)
		assert_int(gate).is_greater(-1)
		assert_that(_override(state, gate, "is_core")).is_null()


# --- The Sun Station ---------------------------------------------------------

func _sun_station() -> SunStation:
	var station := auto_free(load("res://entities/structures/SunStation.tscn").instantiate()) as SunStation
	station.enable_orbiting = false
	add_child(station)
	return station


func _home_station() -> SpaceStation:
	var station := auto_free(load("res://entities/structures/SpaceStation.tscn").instantiate()) as SpaceStation
	station.enable_orbiting = false
	add_child(station)
	return station


func test_the_sun_station_keeps_out_of_the_home_stations_group() -> void:
	var station := _sun_station()
	assert_bool(station.is_in_group("space_stations")).is_false()
	assert_bool(station.is_in_group("sun_station")).is_true()
	assert_bool(_home_station().is_in_group("space_stations")).is_true()


## Home tracking, the chart's home label and the Void's guard all read the first node
## in "space_stations", and that has to stay Rook's however the tree is walked.
func test_home_is_still_the_only_thing_in_the_home_stations_group() -> void:
	_sun_station()
	var home := _home_station()
	var found := get_tree().get_nodes_in_group("space_stations")
	assert_int(found.size()).is_equal(1)
	assert_object(get_tree().get_first_node_in_group("space_stations")).is_same(home)


func test_the_sun_station_can_be_docked_at() -> void:
	var station := _sun_station()
	var ports: Array[SpacePort] = []
	for child in station.get_children():
		if child is SpacePort:
			ports.append(child as SpacePort)
	assert_int(ports.size()).is_greater(0)
	for port in ports:
		assert_bool(port.is_in_group("dockable")).is_true()


# --- The Core's Gate ---------------------------------------------------------

func _core_gate() -> Gate:
	var sun := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	sun.name = "Sun"
	sun.radius = 400.0
	sun.enable_orbiting = false
	add_child(sun)
	for grown in sun.get_ore_deposits():
		grown.free()
	var gate := auto_free(load("res://entities/structures/Gate.tscn").instantiate()) as Gate
	gate.is_core = true
	gate.power_cost = 0
	gate.enable_orbiting = false
	sun.add_child(gate)
	return gate


## Bring every Module online without going anywhere near the Core.
func _all_modules_online() -> void:
	for planet in ["Veld", "Crom", "Sonder", "Roke", "TERRA-0"]:
		_gs.mark_gate_powered(planet)


func test_the_cores_gate_is_dockable_the_same_way_a_modules_gate_is() -> void:
	var gate := _core_gate()
	assert_bool(gate.is_in_group("dockable")).is_true()
	assert_bool(gate.is_in_group("gates")).is_true()
	assert_str(FlyingState.docked_state_for(gate)).is_equal("GateDockedState")


func test_the_cores_gate_waits_on_every_module_not_on_credits() -> void:
	var gate := _core_gate()
	assert_bool(gate.modules_ready(_gs)).is_false()
	_all_modules_online()
	assert_int(_gs.titan_influence()).is_equal(Gate.MODULE_COUNT)
	assert_bool(gate.modules_ready(_gs)).is_true()


## Inert: even with every Module online the Core takes no power yet, and nothing about
## the Titan moves. The endgame lands in a later issue.
func test_powering_the_cores_gate_does_nothing_yet() -> void:
	var gate := _core_gate()
	_all_modules_online()
	_gs.credits = 5000
	assert_bool(gate.power(_gs)).is_false()
	assert_bool(gate.is_powered()).is_false()
	assert_int(_gs.credits).is_equal(5000)
	assert_int(_gs.titan_influence()).is_equal(Gate.MODULE_COUNT)


func test_the_cores_gate_is_never_a_transit_destination() -> void:
	assert_bool(_core_gate().offers_transit()).is_false()
	var module_gate := auto_free(load("res://entities/structures/Gate.tscn").instantiate()) as Gate
	add_child(module_gate)
	assert_bool(module_gate.offers_transit()).is_true()


# --- The Core's terminal -----------------------------------------------------

func _terminal(gate: Gate) -> GateTerminal:
	var terminal := auto_free(GateTerminal.new()) as GateTerminal
	add_child(terminal)
	terminal.gate = gate
	terminal.gs = _gs
	terminal._refresh_hub()
	return terminal


func test_the_terminal_refuses_the_core_without_counting_the_modules() -> void:
	var terminal := _terminal(_core_gate())
	var row: Dictionary = terminal._menu_items[0]
	assert_bool(row["enabled"]).is_false()
	assert_str(row["label"]).is_equal("POWER INSUFFICIENT")
	assert_str(row["right"]).is_equal("MODULES OFFLINE")

	# Two of the five online reads exactly the same: the terminal never tallies them.
	_gs.mark_gate_powered("Veld")
	_gs.mark_gate_powered("Crom")
	terminal._refresh_hub()
	assert_bool(terminal._menu_items[0]["enabled"]).is_false()
	assert_str(terminal._menu_items[0]["right"]).is_equal("MODULES OFFLINE")
	# The rows the first draw put up are queued for release; let them go
	await await_idle_frame()


func test_the_terminal_offers_the_core_once_every_module_is_online() -> void:
	_all_modules_online()
	var terminal := _terminal(_core_gate())
	var row: Dictionary = terminal._menu_items[0]
	assert_bool(row["enabled"]).is_true()
	assert_str(row["label"]).is_equal("POWER CORE")
	# Nothing to pay: the Core asks for Modules, not credits
	assert_str(row["right"]).is_equal("")


func test_taking_the_core_row_changes_nothing() -> void:
	_all_modules_online()
	_gs.credits = 900
	var gate := _core_gate()
	var terminal := _terminal(gate)
	terminal._selected_index = 0
	terminal._activate_selection()
	assert_int(_gs.credits).is_equal(900)
	assert_int(_gs.titan_influence()).is_equal(Gate.MODULE_COUNT)
	assert_bool(gate.is_powered()).is_false()


## A planet's Gate still asks for its credits; the Core's row is the Core's alone.
func test_a_modules_terminal_is_untouched() -> void:
	var planet := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	planet.name = "Veld"
	planet.radius = 400.0
	planet.enable_orbiting = false
	add_child(planet)
	for grown in planet.get_ore_deposits():
		grown.free()
	var gate := auto_free(load("res://entities/structures/Gate.tscn").instantiate()) as Gate
	gate.power_cost = 600
	gate.enable_orbiting = false
	planet.add_child(gate)
	_gs.credits = 600

	var terminal := _terminal(gate)
	var row: Dictionary = terminal._menu_items[0]
	assert_bool(row["enabled"]).is_true()
	assert_str(row["label"]).is_equal("POWER GATE")
	assert_str(row["right"]).is_equal("600 CR")
