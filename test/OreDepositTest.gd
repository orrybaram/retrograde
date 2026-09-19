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


func test_chunks_sit_just_under_the_surface_and_are_stable() -> void:
	var chunks := OreDeposit.shape_chunks(false, 1234)
	assert_int(chunks.size()).is_between(OreDeposit.CHUNK_COUNT.x, OreDeposit.CHUNK_COUNT.y)
	for chunk in chunks:
		# Local +x points out of the surface, so the chunks are at negative x
		assert_float(-chunk["pos"].x).is_between(OreDeposit.DEPTH_MIN, OreDeposit.DEPTH_MAX)
		assert_float(absf(chunk["pos"].y)).is_less_equal(OreDeposit.CLUSTER)
		assert_float(chunk["size"]).is_between(OreDeposit.CHUNK_MIN, OreDeposit.CHUNK_MAX)
		assert_float(chunk["turn"]).is_between(0.0, TAU)
	# Ordered shallowest first, the order the bit reaches them in
	for i in chunks.size() - 1:
		assert_float(-chunks[i]["pos"].x).is_less_equal(-chunks[i + 1]["pos"].x)
	# Same seed, same seam
	assert_array(OreDeposit.shape_chunks(false, 1234)).is_equal(chunks)
	assert_array(OreDeposit.shape_chunks(false, 99)).is_not_equal(chunks)


func test_chunks_are_scattered_not_strung_out_in_a_line() -> void:
	# Depths vary as much as the sideways spread does, so a seam reads as a cluster
	var depths := []
	var sideways := []
	for seed_value in 40:
		for chunk in OreDeposit.shape_chunks(true, seed_value):
			depths.append(-chunk["pos"].x)
			sideways.append(chunk["pos"].y)
	var depth_span: float = depths.max() - depths.min()
	var side_span: float = sideways.max() - sideways.min()
	assert_float(depth_span).is_greater(OreDeposit.CLUSTER)
	assert_float(depth_span / side_span).is_between(0.5, 2.0)


func test_rich_seams_are_bigger() -> void:
	var plain := OreDeposit.shape_chunks(false, 7)
	var rich := OreDeposit.shape_chunks(true, 7)
	assert_int(rich.size()).is_between(OreDeposit.RICH_CHUNK_COUNT.x, OreDeposit.RICH_CHUNK_COUNT.y)
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
	assert_int(Planet.ORE_COUNT.x).is_greater(1)
	for ore in rocky.get_ore_deposits():
		assert_bool(ore.rich).is_false()
		assert_float(ore.angle_degrees).is_between(0.0, 360.0)


func test_a_moon_grows_rich_seams() -> void:
	var host := _grown_planet(4000.0)
	var moon := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	moon.radius = 400.0
	host.add_child(moon)
	var seams := moon.get_ore_deposits()
	assert_int(seams.size()).is_between(Planet.MOON_ORE_COUNT.x, Planet.MOON_ORE_COUNT.y)
	for seam in seams:
		assert_bool(seam.rich).is_true()


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


func test_rock_takes_on_the_color_of_the_crust_it_sits_in() -> void:
	var warm := OreDeposit.crust_tone(Colors.ORE_ROCK, Color(0.45, 0.30, 0.25), OreDeposit.CRUST_SHADE)
	# A warm crust pulls the neutral rock warm, without lifting it out of the dark
	assert_float(warm.r).is_greater(Colors.ORE_ROCK.r)
	assert_float(warm.r).is_greater(warm.b)
	assert_float(warm.v).is_less(Color(0.45, 0.30, 0.25).v)
	# A cold crust pulls it the other way
	var cold := OreDeposit.crust_tone(Colors.ORE_ROCK, Color(0.25, 0.30, 0.45), OreDeposit.CRUST_SHADE)
	assert_float(cold.b).is_greater(cold.r)
	# The rim reads lighter than the body, and the fracture lines lighter again
	var crust := Color(0.45, 0.30, 0.25)
	var edge := OreDeposit.crust_tone(Colors.ORE_ROCK_EDGE, crust, OreDeposit.CRUST_RIM_SHADE)
	var facet := OreDeposit.crust_tone(Colors.ORE_ROCK_FACET, crust, -OreDeposit.CRUST_FACET_TINT)
	assert_float(edge.v).is_greater(warm.v)
	assert_float(facet.v).is_greater(edge.v)


func test_a_seam_re_mixes_its_rock_when_the_planet_changes_color() -> void:
	var planet := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	planet.color = Color(0.45, 0.30, 0.25)
	add_child(planet)
	var ore := OreDeposit.new()
	planet.add_child(ore)
	ore._match_crust()
	var warm := ore._rock
	planet.color = Color(0.25, 0.30, 0.45)
	ore._match_crust()
	assert_bool(ore._rock.is_equal_approx(warm)).is_false()
	assert_float(ore._rock.b).is_greater(ore._rock.r)
