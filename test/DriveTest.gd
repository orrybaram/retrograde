extends GdUnitTestSuite

## The Drive on its own, no scene tree (entities/Ship/Drive.gd, docs/adr/0010): whether
## the Burn is lit, the cough a low tank gives it, the free quarter, and clamping. The
## Aux is never modelled here, so nothing the Drive does can take ordinary thrust away.

const STEP := 1.0 / 60.0


func _drive(fuel: float) -> Drive:
	var drive := Drive.new()
	drive.rng.seed = 7
	drive.fuel = fuel
	return drive


## Fly `seconds` in steps; returns how many coughs started.
func _fly(drive: Drive, seconds: float, attempting: bool) -> int:
	var coughs := [0]
	var count := func() -> void: coughs[0] += 1
	drive.coughed.connect(count)
	var t := 0.0
	while t < seconds:
		drive.tick(STEP, attempting)
		t += STEP
	drive.coughed.disconnect(count)
	return coughs[0]


# --- Lit ---------------------------------------------------------------------

func test_the_burn_lights_with_boost_thrust_and_fuel() -> void:
	var drive := _drive(Drive.CAPACITY)
	drive.tick(STEP, true)
	assert_bool(drive.is_lit()).is_true()


func test_the_burn_is_dark_without_the_boost_and_thrust() -> void:
	var drive := _drive(Drive.CAPACITY)
	drive.tick(STEP, false)
	assert_bool(drive.is_lit()).is_false()
	assert_bool(drive.try_burn(1.0)).is_false()
	assert_float(drive.fuel).is_equal(Drive.CAPACITY)


func test_a_lit_burn_spends_the_tank() -> void:
	var drive := _drive(Drive.CAPACITY)
	drive.burn_rate = 15.0
	drive.tick(STEP, true)
	assert_bool(drive.try_burn(2.0)).is_true()
	assert_float(drive.fuel).is_equal(Drive.CAPACITY - 30.0)


func test_resting_puts_the_burn_out() -> void:
	var drive := _drive(Drive.CAPACITY)
	drive.tick(STEP, true)
	drive.rest()
	assert_bool(drive.is_lit()).is_false()


func test_the_last_of_the_tank_burns_to_zero_and_says_so() -> void:
	var drive := _drive(1.0)
	drive.burn_rate = 15.0
	var depleted := [0]
	drive.depleted.connect(func() -> void: depleted[0] += 1)
	drive.tick(STEP, true)
	assert_bool(drive.try_burn(1.0)).is_true()
	assert_float(drive.fuel).is_equal(0.0)
	assert_int(depleted[0]).is_equal(1)
	assert_bool(drive.is_lit()).is_false()


# --- Cough -------------------------------------------------------------------

func test_a_full_tank_never_coughs() -> void:
	var drive := _drive(Drive.CAPACITY)
	assert_int(_fly(drive, 10.0, true)).is_equal(0)


## The Aux is free: thrust without the boost never coughs, however low the tank.
func test_the_aux_never_coughs_on_a_low_or_dry_tank() -> void:
	for fuel in [Drive.CAPACITY * 0.2, Drive.CAPACITY * 0.05, 0.0]:
		var drive := _drive(fuel)
		assert_int(_fly(drive, 10.0, false)).is_equal(0)
		assert_bool(drive.is_coughing()).is_false()


func test_a_burn_on_a_critical_tank_coughs_often() -> void:
	var drive := _drive(Drive.CAPACITY * 0.05)
	drive.infinite = true  # hold the level still while the burn runs
	# Critical gaps are 0.25-0.8 s apart plus a 0.2-0.4 s cough: at least 5 in 10 s
	assert_int(_fly(drive, 10.0, true)).is_greater_equal(5)


func test_a_burn_on_a_low_tank_coughs_rarely() -> void:
	var drive := _drive(Drive.CAPACITY * 0.2)
	drive.infinite = true
	# Low gaps are 1.2-2.8 s: some coughs in 10 s, but no more than 8
	var coughs := _fly(drive, 10.0, true)
	assert_int(coughs).is_greater_equal(2)
	assert_int(coughs).is_less_equal(8)


func test_a_cough_puts_the_burn_out_for_its_length() -> void:
	var drive := _drive(Drive.CAPACITY * 0.05)
	drive.infinite = true
	var t := 0.0
	while not drive.is_coughing() and t < 5.0:
		drive.tick(STEP, true)
		t += STEP
	assert_bool(drive.is_coughing()).is_true()
	assert_bool(drive.is_lit()).is_false()
	assert_bool(drive.try_burn(STEP)).is_false()
	# No cough outlasts COUGH_LENGTH, even with the boost let go
	var length := 0.0
	while drive.is_coughing():
		drive.tick(STEP, false)
		length += STEP
	assert_float(length).is_less_equal(Drive.COUGH_LENGTH.y + STEP)
	drive.tick(STEP, true)
	assert_bool(drive.is_lit()).is_true()


## Nothing to burn, and the engine says so: a boost tried on an empty tank coughs, and
## never lights.
func test_a_boost_tried_on_a_dry_tank_coughs_and_never_lights() -> void:
	var drive := _drive(0.0)
	var lit := false
	var coughs := [0]
	drive.coughed.connect(func() -> void: coughs[0] += 1)
	for i in 600:
		drive.tick(STEP, true)
		lit = lit or drive.is_lit() or drive.try_burn(STEP)
	assert_bool(lit).is_false()
	assert_int(coughs[0]).is_greater(0)
	assert_float(drive.fuel).is_equal(0.0)


func test_a_fuller_tank_clears_the_cough_at_once() -> void:
	var drive := _drive(Drive.CAPACITY * 0.05)
	drive.infinite = true
	while not drive.is_coughing():
		drive.tick(STEP, true)
	drive.fuel = Drive.CAPACITY
	drive.tick(STEP, true)
	assert_bool(drive.is_coughing()).is_false()
	assert_bool(drive.is_lit()).is_true()


func test_resting_ends_a_cough_and_the_warning() -> void:
	var drive := _drive(Drive.CAPACITY * 0.05)
	drive.infinite = true
	while not drive.is_coughing():
		drive.tick(STEP, true)
	assert_int(drive.warning()).is_equal(Drive.Level.CRITICAL)
	drive.rest()
	assert_bool(drive.is_coughing()).is_false()
	assert_int(drive.warning()).is_equal(Drive.Level.OK)
	assert_int(drive.level()).is_equal(Drive.Level.CRITICAL)


# --- Refuelling and clamping -------------------------------------------------

func test_writes_clamp_to_the_tank_and_signal() -> void:
	var drive := _drive(0.0)
	var changed := [0]
	drive.changed.connect(func() -> void: changed[0] += 1)
	drive.fuel = Drive.CAPACITY * 3.0
	assert_float(drive.fuel).is_equal(Drive.CAPACITY)
	drive.fuel = -10.0
	assert_float(drive.fuel).is_equal(0.0)
	assert_int(changed[0]).is_equal(2)


func test_refuel_stops_at_the_tank_and_reports_what_it_added() -> void:
	var drive := _drive(Drive.CAPACITY - 10.0)
	assert_float(drive.refuel(50.0)).is_equal(10.0)
	assert_float(drive.fuel).is_equal(Drive.CAPACITY)
	assert_float(drive.refuel(5.0)).is_equal(0.0)


func test_refuel_stops_at_its_target_and_never_drains() -> void:
	var drive := _drive(10.0)
	assert_float(drive.refuel(100.0, 30.0)).is_equal(20.0)
	assert_float(drive.fuel).is_equal(30.0)
	assert_float(drive.refuel(100.0, 5.0)).is_equal(0.0)
	assert_float(drive.fuel).is_equal(30.0)


func test_the_free_floor_is_a_quarter_once_the_core_runs() -> void:
	var drive := _drive(0.0)
	var gs := auto_free(GameState.new()) as GameState
	assert_float(drive.free_floor(null)).is_equal(0.0)
	assert_float(drive.free_floor(gs)).is_equal(0.0)
	gs.core_started = true
	assert_float(drive.free_floor(gs)).is_equal(Drive.CAPACITY * Drive.FREE_FRACTION)
	drive.top_up_to_free_floor(gs)
	assert_float(drive.fuel).is_equal(Drive.CAPACITY * Drive.FREE_FRACTION)
	drive.fuel = Drive.CAPACITY * 0.8
	drive.top_up_to_free_floor(gs)
	assert_float(drive.fuel).is_equal(Drive.CAPACITY * 0.8)


func test_the_infinite_tank_lights_but_never_moves() -> void:
	var drive := _drive(Drive.CAPACITY)
	drive.infinite = true
	drive.tick(STEP, true)
	assert_bool(drive.try_burn(100.0)).is_true()
	assert_float(drive.fuel).is_equal(Drive.CAPACITY)


## A save loading puts the tank back quietly: nothing listening (the radio's low-fuel
## briefing) should take a load for the tank changing.
func test_restore_clamps_without_emitting_changed() -> void:
	var drive := _drive(0.0)
	var changed := [0]
	drive.changed.connect(func() -> void: changed[0] += 1)
	drive.restore(Drive.CAPACITY * 0.25)
	assert_float(drive.fuel).is_equal(Drive.CAPACITY * 0.25)
	drive.restore(Drive.CAPACITY * 3.0)
	assert_float(drive.fuel).is_equal(Drive.CAPACITY)
	drive.restore(-5.0)
	assert_float(drive.fuel).is_equal(0.0)
	assert_int(changed[0]).is_equal(0)
