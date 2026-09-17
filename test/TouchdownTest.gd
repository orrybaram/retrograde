extends GdUnitTestSuite

## Tests for landing on a site: pad detection, touchdown vs hard landing, bounce,
## liftoff fuel cost, and the PlanetLandedState lock / liftoff.

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
	return planet


func _site(planet: Planet, angle := 0.0, revealed := true) -> LandingSite:
	var site := LandingSite.new()
	site.angle_degrees = angle
	planet.add_child(site)
	if revealed:
		_gs.mark_planet_scanned(planet.save_key())
		site.refresh()
	return site


func test_ship_is_over_the_pad_only_within_its_arc() -> void:
	var planet := _planet(400.0)
	var site := _site(planet, 0.0)
	var half := site.pad_half_angle()
	assert_object(Touchdown.site_under(planet, Vector2(420, 0))).is_same(site)
	assert_object(Touchdown.site_under(planet, Vector2.from_angle(half) * 420)).is_same(site)
	assert_object(Touchdown.site_under(planet, Vector2.from_angle(half * 2.0) * 420)).is_null()
	assert_object(Touchdown.site_under(planet, Vector2(-420, 0))).is_null()


func test_hidden_sites_cannot_be_landed_on() -> void:
	var planet := _planet(400.0)
	_site(planet, 0.0, false)
	assert_object(Touchdown.site_under(planet, Vector2(420, 0))).is_null()


func test_slow_and_upright_touches_down() -> void:
	assert_int(Touchdown.judge(Vector2(-10, 5), 0.2, Vector2.RIGHT)).is_equal(LAND)


func test_slow_but_sideways_does_not_land() -> void:
	assert_int(Touchdown.judge(Vector2(-10, 0), PI / 2.0, Vector2.RIGHT)).is_equal(NONE)
	assert_int(Touchdown.judge(Vector2(-10, 0), PI, Vector2.RIGHT)).is_equal(NONE)


func test_fast_into_the_pad_is_a_hard_landing() -> void:
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
	var soft := Touchdown.bounce_velocity(Vector2(-45, 0), Vector2.RIGHT, Vector2.ZERO)
	assert_float(soft.x).is_equal(Touchdown.MIN_BOUNCE_SPEED)


func test_liftoff_cost_scales_with_gravity_and_cargo() -> void:
	var base := Touchdown.liftoff_cost(1.0, 0.0)
	assert_float(base).is_equal(Touchdown.LIFTOFF_FUEL_PER_G)
	assert_float(Touchdown.liftoff_cost(2.0, 0.0)).is_equal_approx(base * 2.0, 0.001)
	assert_float(Touchdown.liftoff_cost(1.0, 80.0)).is_equal_approx(base * 2.0, 0.001)
	assert_float(Touchdown.liftoff_cost(0.5, 160.0)).is_equal_approx(base * 1.5, 0.001)


func test_landed_pose_is_clamped_onto_the_pad() -> void:
	var planet := _planet(400.0)
	var site := _site(planet, 90.0)
	var height := 400.0 + PlanetLandedState.LANDED_HEIGHT
	assert_vector(PlanetLandedState.pad_offset(site, Vector2(3, 430))).is_equal_approx(
		Vector2.from_angle(Vector2(3, 430).angle()) * height, Vector2.ONE * 0.01)
	var far := PlanetLandedState.pad_offset(site, Vector2(-300, 300))
	assert_float(absf(angle_difference(far.angle(), PI / 2.0))).is_equal_approx(site.pad_half_angle(), 0.0001)
	assert_float(far.length()).is_equal_approx(height, 0.01)


func _landed_ship(planet: Planet, site: LandingSite) -> Ship:
	var ship := auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	add_child(ship)
	ship.global_position = site.global_position + site.normal() * 20.0
	ship.set_meta("pending_site", site)
	ship.state_machine.change_state("PlanetLandedState")
	return ship


func test_landed_ship_locks_to_the_planet_and_burns_no_fuel() -> void:
	var planet := _planet(400.0)
	var site := _site(planet, 0.0)
	var ship := _landed_ship(planet, site)
	assert_bool(ship.is_landed_on_planet()).is_true()
	var fuel := ship.fuel
	planet.global_position = Vector2(500, -200)
	await await_millis(PlanetLandedState.SETTLE_TIME * 1000.0 + 150.0)
	var expected := planet.global_position + Vector2(400.0 + PlanetLandedState.LANDED_HEIGHT, 0)
	assert_vector(ship.global_position).is_equal_approx(expected, Vector2.ONE * 1.0)
	assert_float(ship.rotation).is_equal_approx(0.0, 0.01)
	assert_float(ship.fuel).is_equal(fuel)


func test_liftoff_burns_fuel_and_flies_away() -> void:
	var planet := _planet(400.0)
	var site := _site(planet, 0.0)
	var ship := _landed_ship(planet, site)
	InventoryManager.add_item("crystal", 20)
	var state := ship.state_machine.current_state as PlanetLandedState
	var cost := state.liftoff_cost()
	assert_float(cost).is_equal_approx(Touchdown.liftoff_cost(planet.surface_gravity(), 40.0), 0.001)
	var fuel := ship.fuel
	state.lift_off()
	assert_float(ship.fuel).is_equal_approx(fuel - cost, 0.001)
	await await_millis(100)
	assert_str(ship.state_machine.get_current_state_name()).is_equal("FlyingState")
	assert_float((ship.linear_velocity - planet.linear_velocity).dot(Vector2.RIGHT)).is_greater(0.0)


func test_liftoff_without_enough_fuel_burns_the_tank_dry() -> void:
	var planet := _planet(400.0)
	var site := _site(planet, 0.0)
	var ship := _landed_ship(planet, site)
	var state := ship.state_machine.current_state as PlanetLandedState
	ship.fuel = state.liftoff_cost() * 0.5
	var depleted := [false]
	ship.fuel_depleted.connect(func(): depleted[0] = true)
	state.lift_off()
	assert_float(ship.fuel).is_equal(0.0)
	assert_bool(depleted[0]).is_true()
	await await_millis(100)
	assert_str(ship.state_machine.get_current_state_name()).is_equal("PlanetLandedState")
