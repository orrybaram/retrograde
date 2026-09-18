extends GdUnitTestSuite

## Tests for landing near an ore seam: reach detection, touchdown vs hard landing,
## bounce, and the PlanetLandedState lock / liftoff.

const LAND := Touchdown.Result.LAND
const HARD := Touchdown.Result.HARD
const NONE := Touchdown.Result.NONE

var _gs: GameState


func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	add_child(_gs)
	InventoryManager.clear_inventory()


func after_test() -> void:
	InventoryManager.clear_inventory()


func _planet(radius := 400.0) -> Planet:
	var planet := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	planet.radius = radius
	planet.enable_orbiting = false
	add_child(planet)
	# Planets grow their own seams; these tests place their own
	for grown in planet.get_ore_deposits():
		grown.free()
	return planet


func _ore(planet: Planet, angle := 0.0, revealed := true) -> OreDeposit:
	var ore := OreDeposit.new()
	ore.angle_degrees = angle
	ore.ore_index = 9
	planet.add_child(ore)
	if revealed:
		_gs.mark_planet_scanned(planet.save_key())
		ore.refresh()
	return ore


func test_ship_is_in_reach_of_a_seam_only_within_its_arc() -> void:
	var planet := _planet(400.0)
	var ore := _ore(planet, 0.0)
	var reach := ore.reach_angle()
	assert_object(Touchdown.ore_under(planet, Vector2(420, 0))).is_same(ore)
	assert_object(Touchdown.ore_under(planet, Vector2.from_angle(reach) * 420)).is_same(ore)
	assert_object(Touchdown.ore_under(planet, Vector2.from_angle(reach * 2.0) * 420)).is_null()
	assert_object(Touchdown.ore_under(planet, Vector2(-420, 0))).is_null()


func test_hidden_seams_cannot_be_landed_on() -> void:
	var planet := _planet(400.0)
	_ore(planet, 0.0, false)
	assert_object(Touchdown.ore_under(planet, Vector2(420, 0))).is_null()


func test_slow_and_upright_touches_down() -> void:
	assert_int(Touchdown.judge(Vector2(-10, 5), 0.2, Vector2.RIGHT)).is_equal(LAND)


func test_slow_but_sideways_does_not_land() -> void:
	assert_int(Touchdown.judge(Vector2(-10, 0), PI / 2.0, Vector2.RIGHT)).is_equal(NONE)
	assert_int(Touchdown.judge(Vector2(-10, 0), PI, Vector2.RIGHT)).is_equal(NONE)


func test_fast_into_the_ground_is_a_hard_landing() -> void:
	var into := Vector2(-(Touchdown.LANDING_SPEED + 1.0), 0)
	assert_int(Touchdown.judge(into, 0.0, Vector2.RIGHT)).is_equal(HARD)
	# Moving away (just lifted off) is never a hard landing
	assert_int(Touchdown.judge(-into, 0.0, Vector2.RIGHT)).is_equal(NONE)


func test_hard_landing_damages_and_bounces_out() -> void:
	assert_float(Touchdown.hard_damage(Touchdown.LANDING_SPEED + 1.0, 0.5)).is_equal(Touchdown.HARD_DAMAGE_MIN)
	assert_float(Touchdown.hard_damage(Touchdown.LANDING_SPEED + 100.0, 0.5)).is_equal(50.0)
	var planet_vel := Vector2(0, 30)
	var v := Touchdown.bounce_velocity(Vector2(-200, 40), Vector2.RIGHT, planet_vel)
	assert_float((v - planet_vel).x).is_equal_approx(200.0 * Touchdown.BOUNCE, 0.001)
	assert_float((v - planet_vel).y).is_equal_approx(20.0, 0.001)
	# Each bounce keeps only BOUNCE of the impact, so falling back on the same spot
	# converges on a landing instead of bouncing off forever
	var speed := 200.0
	var bounces := 0
	while speed >= Touchdown.LANDING_SPEED and bounces < 20:
		speed = absf(Touchdown.bounce_velocity(Vector2(-speed, 0), Vector2.RIGHT, Vector2.ZERO).x)
		bounces += 1
	assert_float(speed).is_less(Touchdown.LANDING_SPEED)
	assert_int(bounces).is_less(20)


func test_landed_pose_is_held_within_reach_of_the_seam() -> void:
	var planet := _planet(400.0)
	var ore := _ore(planet, 90.0)
	var height := 400.0 + PlanetLandedState.LANDED_HEIGHT
	assert_vector(PlanetLandedState.ground_offset(ore, Vector2(3, 430))).is_equal_approx(
		Vector2.from_angle(Vector2(3, 430).angle()) * height, Vector2.ONE * 0.01)
	var far := PlanetLandedState.ground_offset(ore, Vector2(-300, 300))
	assert_float(absf(angle_difference(far.angle(), PI / 2.0))).is_equal_approx(ore.reach_angle(), 0.0001)
	assert_float(far.length()).is_equal_approx(height, 0.01)


func _landed_ship(planet: Planet, ore: OreDeposit) -> Ship:
	var ship := auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	add_child(ship)
	ship.global_position = ore.global_position + ore.normal() * 20.0
	ship.set_meta("pending_ore", ore)
	ship.state_machine.change_state("PlanetLandedState")
	return ship


func test_landed_ship_locks_to_the_planet_and_burns_no_fuel() -> void:
	var planet := _planet(400.0)
	var ore := _ore(planet, 0.0)
	var ship := _landed_ship(planet, ore)
	assert_bool(ship.is_landed_on_planet()).is_true()
	var fuel := ship.fuel
	planet.global_position = Vector2(500, -200)
	await await_millis(PlanetLandedState.SETTLE_TIME * 1000.0 + 150.0)
	var expected := planet.global_position + Vector2(400.0 + PlanetLandedState.LANDED_HEIGHT, 0)
	assert_vector(ship.global_position).is_equal_approx(expected, Vector2.ONE * 1.0)
	assert_float(ship.rotation).is_equal_approx(0.0, 0.01)
	assert_float(ship.fuel).is_equal(fuel)


func test_liftoff_costs_nothing_and_releases_the_ship_under_its_own_power() -> void:
	var planet := _planet(400.0)
	var ore := _ore(planet, 0.0)
	var ship := _landed_ship(planet, ore)
	InventoryManager.add_item("crystal", 20)
	var state := ship.state_machine.current_state as PlanetLandedState
	var fuel := ship.fuel
	state.lift_off()
	# Breaking ground is free - only the climb costs fuel, and that is ordinary thrust
	assert_float(ship.fuel).is_equal(fuel)
	await await_millis(100)
	assert_str(ship.state_machine.get_current_state_name()).is_equal("FlyingState")
	# Nothing is thrown: the ship is handed over at rest relative to the planet and has to
	# fly itself off the surface
	assert_float((ship.linear_velocity - planet.linear_velocity).length()).is_less(1.0)
	# ...and the ground rules are held off so it isn't judged as landing again at once
	var flying := ship.state_machine.current_state as FlyingState
	assert_bool(flying.is_ignoring_ground()).is_true()


func test_an_empty_tank_still_releases_the_ship_it_just_cannot_climb() -> void:
	var planet := _planet(400.0)
	var ore := _ore(planet, 0.0)
	var ship := _landed_ship(planet, ore)
	var state := ship.state_machine.current_state as PlanetLandedState
	ship.fuel = 0.0
	var depleted := [false]
	ship.fuel_depleted.connect(func(): depleted[0] = true)
	state.lift_off()
	# Nothing is taken and nothing is faked: with no fuel the engines simply never fire,
	# so the ship comes straight back down (see landing.play for the stranding it leads to)
	assert_float(ship.fuel).is_equal(0.0)
	assert_bool(depleted[0]).is_false()
	await await_millis(100)
	assert_str(ship.state_machine.get_current_state_name()).is_equal("FlyingState")
	assert_float((ship.linear_velocity - planet.linear_velocity).length()).is_less(1.0)


func test_a_seam_refilling_under_a_landed_ship_gets_a_fresh_drill() -> void:
	var planet := _planet(400.0)
	var ore := _ore(planet, 0.0)
	ore.spend()
	var ship := _landed_ship(planet, ore)
	var state := ship.state_machine.current_state as PlanetLandedState
	assert_str(state.drill.end_reason).is_equal("spent")
	_gs.tick_ore_regrowth(OreDeposit.RICH_REGROW_TIME)
	await await_millis(100)
	assert_int(state.drill.phase).is_equal(OreDrill.Phase.READY)
	assert_object(ship.get_node_or_null("OreDrill")).is_same(state.drill)
