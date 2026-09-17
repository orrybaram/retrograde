extends GdUnitTestSuite

## Tests for ore seams: where a planet grows them, their shape, riding the planet,
## surfacing on a scan, and the tracking / minimap targets.

var _gs: GameState


func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	add_child(_gs)


func _planet(pos := Vector2.ZERO, radius := 400.0, type := Planet.PlanetType.ROCKY) -> Planet:
	var planet := _grown_planet(radius, type)
	planet.global_position = pos
	# Planets grow their own seams; these tests place their own
	for grown in planet.get_ore_deposits():
		grown.free()
	return planet


## A planet with the ore seams it grew itself (Planet.tscn spawns them on _ready).
func _grown_planet(radius := 400.0, type := Planet.PlanetType.ROCKY) -> Planet:
	var planet := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	planet.radius = radius
	planet.planet_type = type
	add_child(planet)
	return planet


func _ore(planet: Planet, angle := 90.0, rich := false) -> OreDeposit:
	var ore := OreDeposit.new()
	ore.angle_degrees = angle
	ore.rich = rich
	planet.add_child(ore)
	return ore


func test_seam_sits_on_the_surface_facing_out() -> void:
	var planet := _planet(Vector2(1000, 500), 400.0)
	var ore := _ore(planet, 90.0)
	assert_vector(ore.global_position).is_equal_approx(Vector2(1000, 900), Vector2.ONE * 0.01)
	assert_vector(ore.normal()).is_equal_approx(Vector2.DOWN, Vector2.ONE * 0.001)
	assert_float(ore.reach_angle()).is_equal_approx(OreDeposit.REACH / 400.0, 0.0001)


func test_hexes_sit_just_under_the_surface_and_are_stable() -> void:
	var hexes := OreDeposit.shape_hexes(false, 1234)
	assert_int(hexes.size()).is_between(OreDeposit.HEX_COUNT.x, OreDeposit.HEX_COUNT.y)
	for hex in hexes:
		# Local +x points out of the surface, so the hexes are at negative x
		assert_float(-hex["pos"].x).is_between(OreDeposit.DEPTH_MIN, OreDeposit.DEPTH_MAX)
		assert_float(absf(hex["pos"].y)).is_less_equal(OreDeposit.REACH * OreDeposit.SPREAD)
		assert_float(hex["size"]).is_between(OreDeposit.HEX_MIN, OreDeposit.HEX_MAX)
	# Same seed, same seam
	assert_array(OreDeposit.shape_hexes(false, 1234)).is_equal(hexes)
	assert_array(OreDeposit.shape_hexes(false, 99)).is_not_equal(hexes)


func test_rich_seams_are_bigger() -> void:
	var plain := OreDeposit.shape_hexes(false, 7)
	var rich := OreDeposit.shape_hexes(true, 7)
	assert_int(rich.size()).is_between(OreDeposit.RICH_HEX_COUNT.x, OreDeposit.RICH_HEX_COUNT.y)
	assert_int(rich.size()).is_greater(plain.size())


func test_seam_rides_along_with_its_planet() -> void:
	var planet := _planet(Vector2.ZERO, 400.0)
	var ore := _ore(planet, 0.0)
	planet.global_position = Vector2(-300, 250)
	assert_vector(ore.global_position).is_equal_approx(Vector2(100, 250), Vector2.ONE * 0.01)
	planet.linear_velocity = Vector2(12, -3)
	assert_vector(ore.velocity()).is_equal(Vector2(12, -3))
	_gs.mark_planet_scanned(planet.save_key())
	ore.refresh()
	assert_vector(ore.tracking_target().get_velocity()).is_equal(Vector2(12, -3))


func test_seam_is_hidden_until_its_planet_is_scanned() -> void:
	var planet := _planet()
	var other := _planet(Vector2(5000, 0))
	var ore := _ore(planet)
	assert_bool(ore.is_revealed()).is_false()
	assert_bool(ore.visible).is_false()
	assert_bool(ore.tracking_target().is_valid()).is_false()
	assert_bool(OreMinimapTarget.new(ore).is_minimap_visible()).is_false()

	_gs.mark_planet_scanned(other.save_key())
	EventBus.planet_scanned.emit(other)
	assert_bool(ore.is_revealed()).is_false()

	_gs.mark_planet_scanned(planet.save_key())
	EventBus.planet_scanned.emit(planet)
	assert_bool(ore.is_revealed()).is_true()
	assert_bool(ore.visible).is_true()
	assert_bool(ore.tracking_target().is_valid()).is_true()
	assert_bool(OreMinimapTarget.new(ore).is_minimap_visible()).is_true()


func test_loaded_scans_surface_seams_and_new_games_bury_them() -> void:
	var planet := _planet()
	var ore := _ore(planet)
	_gs.mark_planet_scanned(planet.save_key())
	EventBus.planets_restored.emit()
	assert_bool(ore.is_revealed()).is_true()
	_gs.reset_all_state()
	EventBus.planets_restored.emit()
	assert_bool(ore.is_revealed()).is_false()


func test_readout_counts_seams_and_scanner_picks_the_nearest() -> void:
	var planet := _planet(Vector2.ZERO, 400.0)
	var east := _ore(planet, 0.0)
	var west := _ore(planet, 180.0)
	assert_str("\n".join(PlanetScan.readout_lines(planet))).contains("2 SEAMS")
	assert_object(PlanetScanner.nearest_ore(planet, Vector2(900, 0))).is_same(east)
	assert_object(PlanetScanner.nearest_ore(planet, Vector2(-900, 50))).is_same(west)


func test_seam_ids_are_unique_per_planet() -> void:
	var planet := _planet()
	var a := _ore(planet)
	var b := _ore(planet)
	b.ore_index = 1
	assert_str(a.ore_id()).is_not_equal(b.ore_id())
	assert_str(a.ore_id()).starts_with(planet.save_key() + "#")


func test_planets_grow_their_own_seams_but_the_sun_and_gas_giants_do_not() -> void:
	# Planet.tscn spawns them on _ready, so this is what the world actually gets
	assert_int(_grown_planet(400.0, Planet.PlanetType.SUN).get_ore_deposits().size()).is_equal(0)
	assert_int(_grown_planet(400.0, Planet.PlanetType.GAS_GIANT).get_ore_deposits().size()).is_equal(0)
	var rocky := _grown_planet(400.0)
	assert_int(rocky.get_ore_deposits().size()).is_between(Planet.ORE_COUNT.x, Planet.ORE_COUNT.y)
	for ore in rocky.get_ore_deposits():
		assert_bool(ore.rich).is_false()
		assert_float(ore.angle_degrees).is_between(0.0, 360.0)


func test_a_moon_grows_one_rich_seam() -> void:
	var host := _grown_planet(4000.0)
	var moon := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	moon.radius = 400.0
	host.add_child(moon)
	var seams := moon.get_ore_deposits()
	assert_int(seams.size()).is_equal(1)
	assert_bool(seams[0].rich).is_true()


func test_a_planet_grows_the_same_seams_every_session() -> void:
	var first := _grown_planet(400.0)
	first.name = "Twin"
	for grown in first.get_ore_deposits():
		grown.free()
	first._spawn_ore()
	var angles := first.get_ore_deposits().map(func(o: OreDeposit): return o.angle_degrees)
	# A planet with the same save key seeds the same seams
	for child in first.get_ore_deposits():
		child.free()
	first._spawn_ore()
	assert_array(first.get_ore_deposits().map(func(o: OreDeposit): return o.angle_degrees)).is_equal(angles)
