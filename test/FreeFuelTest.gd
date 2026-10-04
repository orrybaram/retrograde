extends GdUnitTestSuite

## Tests for SR-7's free half (docs/FREIGHT.md §8): once its core is running, every dock
## and every relaunch tops the tank up to half of `max_fuel`, never higher. A cold
## SR-7 gives nothing, and fuel past half only ever comes out of Stores.
##
## The GameState is kept out of the tree on purpose, so the dock's autosave finds nothing
## to save and never touches the player's save file.


func _gs(core_started: bool) -> GameState:
	var gs := auto_free(GameState.new()) as GameState
	if core_started:
		gs.progress.flag(Progress.CORE_STARTED)
	return gs


func _ship(fuel: float) -> Ship:
	var ship := auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	add_child(ship)
	ship.drive.fuel = fuel
	return ship


func _landed(ship: Ship) -> LandedState:
	var state := auto_free(LandedState.new()) as LandedState
	state.entity = ship
	return state


## Runs the dock's fill for `seconds`, in small steps, the way physics_process does.
func _dock(state: LandedState, gs: GameState, seconds: float) -> void:
	state._start_refuel(gs)
	var step := 1.0 / 60.0
	var t := 0.0
	while t < seconds and state._refueling:
		state._refuel(step)
		t += step


# --- Docking -----------------------------------------------------------------

func test_a_running_sr7_fills_an_empty_tank_to_half_and_stops() -> void:
	var ship := _ship(0.0)
	var state := _landed(ship)
	_dock(state, _gs(true), LandedState.REFUEL_TIME * 2.0)
	assert_float(ship.drive.fuel).is_equal_approx(ship.drive.max_fuel * 0.5, 0.001)
	assert_bool(state._refueling).is_false()


func test_a_tank_above_half_is_left_alone() -> void:
	var ship := _ship(0.0)
	ship.drive.fuel = ship.drive.max_fuel * 0.6
	var state := _landed(ship)
	state._start_refuel(_gs(true))
	assert_bool(state._refueling).is_false()
	assert_float(ship.drive.fuel).is_equal(ship.drive.max_fuel * 0.6)


func test_a_cold_sr7_gives_nothing_on_the_dock() -> void:
	var ship := _ship(0.0)
	var state := _landed(ship)
	_dock(state, _gs(false), LandedState.REFUEL_TIME * 2.0)
	assert_bool(state._refueling).is_false()
	assert_float(ship.drive.fuel).is_equal(0.0)


## The port's pace is unchanged: half the tank takes half the full-tank time.
func test_the_half_fills_at_the_ports_pace() -> void:
	var ship := _ship(0.0)
	var state := _landed(ship)
	state._start_refuel(_gs(true))
	state._refuel(LandedState.REFUEL_TIME / 8.0)
	assert_float(ship.drive.fuel).is_equal_approx(ship.drive.max_fuel / 8.0, 0.001)
	assert_bool(state._refueling).is_true()


# --- Relaunch ----------------------------------------------------------------

func test_relaunch_tops_an_empty_tank_up_to_half() -> void:
	var ship := _ship(0.0)
	ship.drive.top_up_to_free_floor(_gs(true))
	assert_float(ship.drive.fuel).is_equal_approx(ship.drive.max_fuel * 0.5, 0.001)


func test_relaunch_never_drains_a_tank_above_half() -> void:
	var ship := _ship(0.0)
	ship.drive.fuel = ship.drive.max_fuel * 0.8
	ship.drive.top_up_to_free_floor(_gs(true))
	assert_float(ship.drive.fuel).is_equal(ship.drive.max_fuel * 0.8)


func test_relaunch_before_the_cold_start_gives_nothing() -> void:
	var ship := _ship(0.0)
	ship.drive.top_up_to_free_floor(_gs(false))
	assert_float(ship.drive.fuel).is_equal(0.0)
	ship.drive.top_up_to_free_floor(null)
	assert_float(ship.drive.fuel).is_equal(0.0)


func test_the_floor_is_zero_until_the_core_runs() -> void:
	var ship := _ship(0.0)
	assert_float(ship.drive.free_floor(_gs(false))).is_equal(0.0)
	assert_float(ship.drive.free_floor(_gs(true))).is_equal(ship.drive.max_fuel * Drive.FREE_FRACTION)
