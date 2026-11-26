extends GdUnitTestSuite

## Tests for the sun-facing planet shadow polygon.


func test_shadow_lies_on_far_side_from_light() -> void:
	var to_light := Vector2(1, 1)
	var poly := PlanetVisual.build_shadow_polygon(100.0, to_light, 0.25, 32)
	assert_int(poly.size()).is_greater(3)
	var dir := to_light.normalized()
	for p in poly:
		assert_float(p.dot(dir)).is_less_equal(0.001)


func test_shadow_stays_inside_disc() -> void:
	var poly := PlanetVisual.build_shadow_polygon(50.0, Vector2.LEFT, -0.5, 32)
	for p in poly:
		assert_float(p.length()).is_less_equal(50.001)


func test_shadow_follows_light_direction() -> void:
	var from_right := PlanetVisual.build_shadow_polygon(100.0, Vector2.RIGHT, 0.0, 32)
	var from_up := PlanetVisual.build_shadow_polygon(100.0, Vector2.UP, 0.0, 32)
	assert_float(_centroid(from_right).x).is_less(0.0)
	assert_float(_centroid(from_up).y).is_greater(0.0)


func test_straight_terminator_covers_half_the_disc() -> void:
	var poly := PlanetVisual.build_shadow_polygon(100.0, Vector2.RIGHT, 0.0, 128)
	var half_area := PI * 100.0 * 100.0 / 2.0
	assert_float(_area(poly)).is_equal_approx(half_area, half_area * 0.01)


func test_curve_thins_the_shadow() -> void:
	var flat := _area(PlanetVisual.build_shadow_polygon(100.0, Vector2.RIGHT, 0.0, 64))
	var crescent := _area(PlanetVisual.build_shadow_polygon(100.0, Vector2.RIGHT, 0.5, 64))
	assert_float(crescent).is_less(flat)


func test_degenerate_input_returns_empty() -> void:
	assert_int(PlanetVisual.build_shadow_polygon(0.0, Vector2.RIGHT, 0.2).size()).is_equal(0)
	assert_int(PlanetVisual.build_shadow_polygon(10.0, Vector2.ZERO, 0.2).size()).is_equal(0)


func _centroid(poly: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in poly:
		sum += p
	return sum / poly.size()


func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var j := (i + 1) % poly.size()
		a += poly[i].cross(poly[j])
	return absf(a) / 2.0


func test_planet_color_change_updates_visual() -> void:
	var planet := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	var visual := planet.get_node("PlanetVisual") as PlanetVisual
	planet.color = Color(0.2, 0.4, 0.6, 1.0)
	assert_object(visual.base_color).is_equal(Color(0.2, 0.4, 0.6, 1.0))


func test_glow_boost_strongest_near_sun() -> void:
	assert_float(PlanetVisual.glow_boost_for(10000.0, 50000.0, 250000.0, 1.6)).is_equal_approx(1.6, 0.0001)
	assert_float(PlanetVisual.glow_boost_for(150000.0, 50000.0, 250000.0, 1.6)).is_equal_approx(1.3, 0.0001)
	assert_float(PlanetVisual.glow_boost_for(900000.0, 50000.0, 250000.0, 1.6)).is_equal_approx(1.0, 0.0001)


func test_glow_boost_handles_degenerate_range() -> void:
	assert_float(PlanetVisual.glow_boost_for(10.0, 100.0, 100.0, 1.5)).is_equal(1.5)
	assert_float(PlanetVisual.glow_boost_for(200.0, 100.0, 100.0, 1.5)).is_equal(1.0)


func test_glare_peaks_at_surface_and_fades_out() -> void:
	assert_float(PlanetVisual.glare_alpha_for(900.0, 1000.0, 3.0, 0.5)).is_equal_approx(0.5, 0.0001)
	assert_float(PlanetVisual.glare_alpha_for(1000.0, 1000.0, 3.0, 0.5)).is_equal_approx(0.5, 0.0001)
	assert_float(PlanetVisual.glare_alpha_for(2000.0, 1000.0, 3.0, 0.5)).is_equal_approx(0.0625, 0.0001)
	assert_float(PlanetVisual.glare_alpha_for(3000.0, 1000.0, 3.0, 0.5)).is_equal_approx(0.0, 0.0001)
	assert_float(PlanetVisual.glare_alpha_for(9000.0, 1000.0, 3.0, 0.5)).is_equal_approx(0.0, 0.0001)


func test_glow_brightest_on_sun_side() -> void:
	var to_sun := Vector2.RIGHT
	var lit := PlanetVisual.glow_side_gain(Vector2.RIGHT, to_sun, 2.5, 0.35)
	var side := PlanetVisual.glow_side_gain(Vector2.UP, to_sun, 2.5, 0.35)
	var dark := PlanetVisual.glow_side_gain(Vector2.LEFT, to_sun, 2.5, 0.35)
	assert_float(lit).is_equal_approx(2.5, 0.0001)
	assert_float(dark).is_equal_approx(0.35, 0.0001)
	assert_float(side).is_between(dark, lit)


func test_glow_side_gain_neutral_without_light() -> void:
	assert_float(PlanetVisual.glow_side_gain(Vector2.RIGHT, Vector2.ZERO, 2.5, 0.35)).is_equal(1.0)
