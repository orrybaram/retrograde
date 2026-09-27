extends GdUnitTestSuite

## Tests for PlanetScan: the inner-orbit reach that marks a Body Visited and the survey
## readout its Record holds. The planetary scan itself is gone (docs/OPENING.md §9).

var _gs: GameState


func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	add_child(_gs)



func _planet(pos: Vector2, radius := 100.0, type := Planet.PlanetType.ROCKY) -> Planet:
	var planet := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	planet.radius = radius
	planet.planet_type = type
	add_child(planet)
	planet.global_position = pos
	return planet


func test_reach_is_only_inner_orbit() -> void:
	var planet := _planet(Vector2.ZERO, 100.0)
	var inner := planet.scan_radius()
	assert_float(inner).is_greater(planet.radius)
	assert_float(inner).is_less(planet.field_radius())
	assert_object(PlanetScan.deepest(Vector2(inner - 1.0, 0), [planet])).is_same(planet)
	assert_object(PlanetScan.deepest(Vector2(inner + 1.0, 0), [planet])).is_null()
	# Being inside the gravity field is not enough
	assert_object(PlanetScan.deepest(Vector2(planet.field_radius() - 1.0, 0), [planet])).is_null()


func test_inner_orbit_is_the_first_gravity_ring_clear_of_the_surface() -> void:
	var rings := 6
	var inner := GravityFieldVisual.inner_orbit_radius(100.0, 500.0, rings)
	var below := []
	for i in rings:
		var r := GravityFieldVisual.ring_radius(i, rings, 100.0, 500.0)
		if r <= 100.0:
			below.append(r)
		elif r < inner:
			fail("ring %f sits between the surface and inner orbit" % r)
	assert_array(below).is_not_empty()


func test_deepest_prefers_the_deeper_field() -> void:
	var big := _planet(Vector2(1000, 0), 400.0)
	var moon := _planet(Vector2(1300, 0), 50.0)
	assert_object(PlanetScan.deepest(Vector2(1310, 0), [big, moon])).is_same(moon)


## The sun is a Body like any other: it is reached by the same rule, and its survey
## honestly reports no ore (docs/GLOSSARY.md, Body; docs/adr/0003).
func test_the_sun_reads_like_any_other_body() -> void:
	var sun := _planet(Vector2.ZERO, 5000.0, Planet.PlanetType.SUN)
	sun.planet_name = "Sun"
	var inner := sun.scan_radius()
	assert_object(PlanetScan.deepest(Vector2(inner - 1.0, 0), [sun])).is_same(sun)
	assert_object(PlanetScan.deepest(Vector2(inner + 1.0, 0), [sun])).is_null()
	assert_str("\n".join(PlanetScan.readout_lines(sun))).contains("NONE FOUND")


func test_deepest_ignores_whether_a_body_is_surveyed() -> void:
	var planet := _planet(Vector2.ZERO, 100.0)
	var pos := Vector2(planet.scan_radius() - 1.0, 0)
	assert_object(PlanetScan.deepest(pos, [planet])).is_same(planet)
	_gs.mark_planet_scanned(planet.save_key())
	assert_object(PlanetScan.deepest(pos, [planet])).is_same(planet)


func test_readout_lists_the_survey_data() -> void:
	var planet := _planet(Vector2.ZERO, 100.0, Planet.PlanetType.ICE_GIANT)
	planet.planet_name = "Veld"
	planet.habitability = 0.25
	var text := "\n".join(PlanetScan.readout_lines(planet))
	assert_str(text).contains("VELD")
	assert_str(text).contains("ICE GIANT")
	assert_str(text).contains("25%")
	assert_str(text).contains("%.1f G" % planet.surface_gravity())
	assert_str(text).contains("%d SEAMS" % planet.get_ore_deposits().size())
	assert_str(text).not_contains("ORBITS")


func test_new_game_forgets_surveys() -> void:
	_gs.mark_planet_scanned("Veld/Rook")
	_gs.reset_all_state()
	assert_bool(_gs.is_planet_scanned("Veld/Rook")).is_false()
