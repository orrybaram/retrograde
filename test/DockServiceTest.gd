extends GdUnitTestSuite

## Tests for the dock's spending (issue #137): after the Deposit, SR-7 spends Stores on
## the ship with no menu. The hull is patched first, then the tank is topped up past the
## free quarter, as far as the Stores allow.
##
## The GameState is kept out of the tree on purpose, so the dock's autosave finds nothing
## to save and never touches the player's save file.


func _gs(stores: int) -> GameState:
	var gs := auto_free(GameState.new()) as GameState
	gs.progress.flag(Progress.CORE_STARTED)
	gs.stores = stores
	return gs


func _ship(fuel: float, hull: float) -> Ship:
	var ship := auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	add_child(ship)
	ship.drive.fuel = fuel
	ship.hull_strength = hull
	return ship


func _landed(ship: Ship) -> LandedState:
	var state := auto_free(LandedState.new()) as LandedState
	state.entity = ship
	return state


## Docks and plays the Deposit out at once, then runs the dock's work for `seconds`, in
## small steps, the way physics_process does.
func _dock(state: LandedState, gs: GameState, seconds: float) -> void:
	state._start_refuel(gs)
	state._on_deposit_finished(0, gs)
	var step := 1.0 / 60.0
	var t := 0.0
	while t < seconds:
		state._service(step)
		t += step


func _full_fuel_cost(ship: Ship) -> int:
	return ceili(ship.drive.max_fuel * (1.0 - Drive.FREE_FRACTION) * Economy.REFUEL_COST_PER_POINT)


func test_stores_go_to_the_hull_first() -> void:
	var ship := _ship(0.0, 40.0)
	var gs := _gs(10000)
	var state := _landed(ship)
	state.locked_dockable = ship  # docked: anything non-null
	_dock(state, gs, LandedState.REPAIR_TIME * 0.5)
	# Mid-repair: the tank has had its free quarter and not a drop more
	assert_bool(state._repairing).is_true()
	assert_float(ship.hull_strength).is_greater(40.0)
	assert_float(ship.drive.fuel).is_equal_approx(ship.drive.max_fuel * Drive.FREE_FRACTION, 0.001)
	assert_int(gs.stores).is_less(10000)


func test_with_stores_left_the_tank_fills_past_the_quarter() -> void:
	var ship := _ship(0.0, 40.0)
	var gs := _gs(10000)
	var state := _landed(ship)
	state.locked_dockable = ship
	_dock(state, gs, LandedState.REPAIR_TIME + LandedState.REFUEL_TIME * 2.0)
	assert_float(ship.hull_strength).is_equal(ship.max_hull)
	assert_float(ship.drive.fuel).is_equal(ship.drive.max_fuel)
	var spent := 60 * Economy.REPAIR_COST_PER_POINT + _full_fuel_cost(ship)
	assert_int(gs.stores).is_equal(10000 - spent)
	assert_bool(state._repairing or state._topping_up).is_false()


func test_a_whole_hull_goes_straight_to_the_tank() -> void:
	var ship := _ship(0.0, 100.0)
	ship.drive.fuel = ship.drive.max_fuel * Drive.FREE_FRACTION
	var gs := _gs(1000)
	var state := _landed(ship)
	state.locked_dockable = ship
	_dock(state, gs, LandedState.REFUEL_TIME * 2.0)
	assert_float(ship.drive.fuel).is_equal(ship.drive.max_fuel)
	assert_int(gs.stores).is_equal(1000 - _full_fuel_cost(ship))


func test_too_few_stores_patch_part_of_the_hull_and_reach_zero() -> void:
	var ship := _ship(0.0, 40.0)
	var gs := _gs(30)  # ten hull points
	var state := _landed(ship)
	state.locked_dockable = ship
	_dock(state, gs, LandedState.REPAIR_TIME + LandedState.REFUEL_TIME * 2.0)
	assert_int(gs.stores).is_equal(0)
	assert_float(ship.hull_strength).is_equal_approx(50.0, 0.01)
	# Nothing left for the tank past its free quarter
	assert_float(ship.drive.fuel).is_equal_approx(ship.drive.max_fuel * Drive.FREE_FRACTION, 0.001)


func test_stores_left_after_the_hull_partly_fill_the_tank_and_reach_zero() -> void:
	var ship := _ship(0.0, 90.0)
	var gs := _gs(40)  # 30 on the hull, 10 on fuel
	var state := _landed(ship)
	state.locked_dockable = ship
	_dock(state, gs, LandedState.REPAIR_TIME + LandedState.REFUEL_TIME * 2.0)
	assert_int(gs.stores).is_equal(0)
	assert_float(ship.hull_strength).is_equal(ship.max_hull)
	var expected := ship.drive.max_fuel * Drive.FREE_FRACTION + 10.0 / Economy.REFUEL_COST_PER_POINT
	assert_float(ship.drive.fuel).is_equal_approx(expected, 0.01)


func test_no_stores_buys_nothing() -> void:
	var ship := _ship(0.0, 40.0)
	var gs := _gs(0)
	var state := _landed(ship)
	state.locked_dockable = ship
	_dock(state, gs, LandedState.REPAIR_TIME + LandedState.REFUEL_TIME * 2.0)
	assert_float(ship.hull_strength).is_equal(40.0)
	assert_float(ship.drive.fuel).is_equal_approx(ship.drive.max_fuel * Drive.FREE_FRACTION, 0.001)


func test_a_whole_ship_spends_nothing() -> void:
	var ship := _ship(150.0, 100.0)
	var gs := _gs(500)
	var state := _landed(ship)
	state.locked_dockable = ship
	_dock(state, gs, 1.0)
	assert_int(gs.stores).is_equal(500)


## Taking off mid-spend stops it, and settles the fraction of a Store already run up.
func test_leaving_the_dock_stops_the_spending() -> void:
	var ship := _ship(150.0, 40.0)
	var gs := _gs(10000)
	var state := _landed(ship)
	state.locked_dockable = ship
	_dock(state, gs, 0.5)
	var hull := ship.hull_strength
	state._repairing = false
	state._topping_up = false
	state._settle()
	var stores := gs.stores
	assert_int(stores).is_equal(10000 - ceili((hull - 40.0) * Economy.REPAIR_COST_PER_POINT - 0.0001))
	state._service(1.0)
	assert_float(ship.hull_strength).is_equal(hull)
	assert_int(gs.stores).is_equal(stores)


## A Deposit finished by taking off (exit clears the dock first) starts no spending.
func test_a_deposit_finished_on_takeoff_spends_nothing() -> void:
	var ship := _ship(0.0, 40.0)
	var gs := _gs(500)
	var state := _landed(ship)
	state._on_deposit_finished(0, gs)
	assert_bool(state._repairing or state._topping_up).is_false()
