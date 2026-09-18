extends GdUnitTestSuite

## Tests for transit between powered Gates and the free fill while docked at one.
##
## Transit only exists between Modules that are already online, and the Titan carries
## the ship itself: the point of these tests is that the trip lands the ship in the
## other cradle having spent nothing at all.

var _gs: GameState


func before_test() -> void:
	InventoryManager.clear_inventory()
	_gs = auto_free(GameState.new()) as GameState
	_gs.set_process(false)
	add_child(_gs)


func after_test() -> void:
	InventoryManager.clear_inventory()


## A planet at `orbit` from the sun, with a Gate around it. Orbiting is off so the
## cradle stays put for the assertions.
func _gate(planet_name: String, orbit: float) -> Gate:
	var planet := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	planet.name = planet_name
	planet.planet_name = planet_name
	planet.radius = 400.0
	planet.orbital_distance = orbit
	planet.enable_orbiting = false
	add_child(planet)
	for grown in planet.get_ore_deposits():
		grown.free()
	var gate := auto_free(load("res://entities/structures/Gate.tscn").instantiate()) as Gate
	gate.power_cost = 0
	gate.enable_orbiting = false
	planet.add_child(gate)
	return gate


func _power(gate: Gate) -> Gate:
	_gs.mark_gate_powered(gate.save_key())
	return gate


func _ship() -> Ship:
	var ship := auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	add_child(ship)
	return ship


func _dock_at(ship: Ship, gate: Gate) -> void:
	ship.global_position = gate.get_dock_position()
	ship.set_meta("pending_dockable", gate)
	ship.state_machine.change_state("GateDockedState")


func _labels(items: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for item in items:
		out.append(item["label"])
	return out


# --- The destination list ----------------------------------------------------

func test_the_linked_gates_are_the_other_powered_ones_sun_outwards() -> void:
	var here := _power(_gate("Veld", 253125.0))
	_power(_gate("Crom", 168750.0))
	_power(_gate("TERRA-0", 50000.0))
	var names: Array[String] = []
	for gate in GateTransit.destinations(here, get_tree()):
		names.append(GateTransit.label_for(gate))
	assert_array(names).contains_exactly(["TERRA-0", "CROM"])


## A Gate powers its own Module on its own; the link needs the far end online too.
func test_a_dormant_gate_is_not_a_destination() -> void:
	var here := _power(_gate("Veld", 253125.0))
	_gate("Crom", 168750.0)
	assert_array(GateTransit.destinations(here, get_tree())).is_empty()


func test_the_gate_the_ship_is_sitting_in_is_never_its_own_destination() -> void:
	var here := _power(_gate("Veld", 253125.0))
	assert_array(GateTransit.destinations(here, get_tree())).is_empty()
	assert_bool(GateTransit.can_transit(here, here)).is_false()


func test_transit_needs_both_ends_online() -> void:
	var here := _power(_gate("Veld", 253125.0))
	var dormant := _gate("Crom", 168750.0)
	assert_bool(GateTransit.can_transit(here, dormant)).is_false()
	assert_bool(GateTransit.can_transit(here, _power(dormant))).is_true()


# --- The terminal's transit list ---------------------------------------------

func _terminal() -> GateTerminal:
	var terminal := auto_free(GateTerminal.new()) as GateTerminal
	add_child(terminal)
	return terminal


## Swapping the hub rows for the destination list queues the old ones for freeing;
## letting a frame pass keeps them from being counted as leaks.
func _open_transit(terminal: GateTerminal) -> void:
	terminal._open_transit()
	await get_tree().process_frame


func test_the_transit_list_holds_one_row_per_linked_gate() -> void:
	var here := _power(_gate("Veld", 253125.0))
	_power(_gate("Crom", 168750.0))
	_power(_gate("Roke", 75000.0))
	var terminal := _terminal()
	terminal.open(here)
	await _open_transit(terminal)
	assert_array(_labels(terminal._menu_items)).contains_exactly(["ROKE", "CROM"])


func test_one_powered_gate_on_its_own_has_nowhere_to_go() -> void:
	var here := _power(_gate("Veld", 253125.0))
	var terminal := _terminal()
	terminal.open(here)
	await _open_transit(terminal)
	assert_array(_labels(terminal._menu_items)).contains_exactly(["NO LINKED GATES"])
	assert_bool(terminal._menu_items[0]["enabled"]).is_false()


## The hub only offers transit and the free fill once the Module is online; a dormant
## Gate has nothing but its price.
func test_a_dormant_gates_hub_offers_neither_transit_nor_fuel() -> void:
	var terminal := _terminal()
	terminal.open(_gate("Veld", 253125.0))
	assert_array(_labels(terminal._menu_items)).contains_exactly(["POWER GATE", "DEPART"])


func test_a_powered_gates_hub_offers_transit_and_a_free_fill() -> void:
	var terminal := _terminal()
	terminal.open(_power(_gate("Veld", 253125.0)))
	assert_array(_labels(terminal._menu_items)).contains_exactly(["TRANSIT", "REFUEL", "DEPART"])


# --- The trip itself ---------------------------------------------------------

func test_transit_lands_the_ship_docked_at_the_destination() -> void:
	var here := _power(_gate("Veld", 253125.0))
	var there := _power(_gate("Crom", 168750.0))
	there.global_position = Vector2(-40000, 12000)
	var ship := _ship()
	_dock_at(ship, here)

	GateTransit.arrive(ship, there)

	assert_str(ship.state_machine.get_current_state_name()).is_equal("GateDockedState")
	var state := ship.state_machine.current_state as GateDockedState
	assert_object(state.locked_dockable).is_same(there)
	assert_vector(ship.global_position).is_equal_approx(there.get_dock_position(), Vector2.ONE * 0.01)


## The whole point: the Titan moves the ship, so the ship spends nothing doing it.
func test_transit_costs_no_fuel_hull_hold_or_credits() -> void:
	var here := _power(_gate("Veld", 253125.0))
	var there := _power(_gate("Crom", 168750.0))
	var ship := _ship()
	_dock_at(ship, here)
	ship.fuel = 42.0
	ship.hull_strength = 55.0
	_gs.credits = 1234
	InventoryManager.add_item("gem", 3)
	var hold := InventoryManager.get_total_value()

	GateTransit.arrive(ship, there)

	assert_float(ship.fuel).is_equal(42.0)
	assert_float(ship.hull_strength).is_equal(55.0)
	assert_int(_gs.credits).is_equal(1234)
	assert_int(InventoryManager.get_total_value()).is_equal(hold)
	assert_int(InventoryManager.get_quantity("gem")).is_equal(3)


## Powering a Gate is what costs credits; nothing about the link charges again.
func test_arriving_never_powers_anything_down_or_up() -> void:
	var here := _power(_gate("Veld", 253125.0))
	var there := _power(_gate("Crom", 168750.0))
	var ship := _ship()
	_dock_at(ship, here)
	GateTransit.arrive(ship, there)
	assert_int(_gs.titan_influence()).is_equal(2)
	assert_bool(here.is_powered()).is_true()
	assert_bool(there.is_powered()).is_true()


# --- The free fill -----------------------------------------------------------

func test_the_gate_fills_the_tank_and_deducts_nothing() -> void:
	var gate := _power(_gate("Veld", 253125.0))
	var ship := _ship()
	_dock_at(ship, gate)
	ship.fuel = 0.0
	_gs.credits = 500
	var state := ship.state_machine.current_state as GateDockedState

	state._on_refuel_requested()
	assert_bool(state._refuelling).is_true()
	for i in 10:
		state._refuel(GateDockedState.REFUEL_TIME / 8.0)

	assert_float(ship.fuel).is_equal(ship.max_fuel)
	assert_bool(state._refuelling).is_false()
	assert_int(_gs.credits).is_equal(500)


## A port's pace, without a port's bill.
func test_the_fill_takes_the_same_time_a_port_takes() -> void:
	assert_float(GateDockedState.REFUEL_TIME).is_equal(LandedState.REFUEL_TIME)
	var gate := _power(_gate("Veld", 253125.0))
	var ship := _ship()
	_dock_at(ship, gate)
	ship.fuel = 0.0
	var state := ship.state_machine.current_state as GateDockedState
	state._on_refuel_requested()
	state._refuel(GateDockedState.REFUEL_TIME / 2.0)
	assert_float(ship.fuel).is_equal_approx(ship.max_fuel / 2.0, 0.001)


func test_a_full_tank_asks_for_nothing() -> void:
	var gate := _power(_gate("Veld", 253125.0))
	var ship := _ship()
	_dock_at(ship, gate)
	ship.fuel = ship.max_fuel
	var state := ship.state_machine.current_state as GateDockedState
	state._on_refuel_requested()
	assert_bool(state._refuelling).is_false()
