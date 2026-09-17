extends GdUnitTestSuite

## Tests for landing sites: placement on the rim, riding the planet, reveal on scan,
## tracking/minimap targets, and the home system's site layout.

var _gs: GameState


func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	add_child(_gs)


func _planet(pos := Vector2.ZERO, radius := 400.0) -> Planet:
	var planet := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	planet.radius = radius
	add_child(planet)
	planet.global_position = pos
	return planet


func _site(planet: Planet, angle := 90.0, rich := false) -> LandingSite:
	var site := LandingSite.new()
	site.angle_degrees = angle
	site.rich = rich
	planet.add_child(site)
	return site


func test_site_sits_on_the_rim_facing_out() -> void:
	var planet := _planet(Vector2(1000, 500), 400.0)
	var site := _site(planet, 90.0)
	assert_vector(site.global_position).is_equal_approx(Vector2(1000, 900), Vector2.ONE * 0.01)
	assert_vector(site.normal()).is_equal_approx(Vector2.DOWN, Vector2.ONE * 0.001)
	assert_float(site.pad_half_angle()).is_equal_approx(LandingSite.PAD_WIDTH / 2.0 / 400.0, 0.0001)


func test_site_rides_along_with_its_planet() -> void:
	var planet := _planet(Vector2.ZERO, 400.0)
	var site := _site(planet, 0.0)
	planet.global_position = Vector2(-300, 250)
	assert_vector(site.global_position).is_equal_approx(Vector2(100, 250), Vector2.ONE * 0.01)
	planet.linear_velocity = Vector2(12, -3)
	assert_vector(site.velocity()).is_equal(Vector2(12, -3))
	_gs.mark_planet_scanned(planet.save_key())
	site.refresh()
	assert_vector(site.tracking_target().get_velocity()).is_equal(Vector2(12, -3))


func test_site_is_hidden_until_its_planet_is_scanned() -> void:
	var planet := _planet()
	var other := _planet(Vector2(5000, 0))
	var site := _site(planet)
	assert_bool(site.is_revealed()).is_false()
	assert_bool(site.visible).is_false()
	assert_bool(site.tracking_target().is_valid()).is_false()
	assert_bool(LandingSiteMinimapTarget.new(site).is_minimap_visible()).is_false()

	_gs.mark_planet_scanned(other.save_key())
	EventBus.planet_scanned.emit(other)
	assert_bool(site.is_revealed()).is_false()

	_gs.mark_planet_scanned(planet.save_key())
	EventBus.planet_scanned.emit(planet)
	assert_bool(site.is_revealed()).is_true()
	assert_bool(site.visible).is_true()
	assert_bool(site.tracking_target().is_valid()).is_true()
	assert_bool(LandingSiteMinimapTarget.new(site).is_minimap_visible()).is_true()


func test_loaded_scans_reveal_sites_and_new_games_hide_them() -> void:
	var planet := _planet()
	var site := _site(planet)
	_gs.mark_planet_scanned(planet.save_key())
	EventBus.planets_restored.emit()
	assert_bool(site.is_revealed()).is_true()
	_gs.reset_all_state()
	EventBus.planets_restored.emit()
	assert_bool(site.is_revealed()).is_false()


func test_readout_counts_sites_and_scanner_picks_the_nearest() -> void:
	var planet := _planet(Vector2.ZERO, 400.0)
	var east := _site(planet, 0.0)
	var west := _site(planet, 180.0)
	assert_str("\n".join(PlanetScan.readout_lines(planet))).contains("2 FOUND")
	assert_object(PlanetScanner.nearest_site(planet, Vector2(900, 0))).is_same(east)
	assert_object(PlanetScanner.nearest_site(planet, Vector2(-900, 50))).is_same(west)
	assert_object(PlanetScanner.nearest_site(_planet(Vector2(9000, 0)), Vector2.ZERO)).is_null()


func test_site_ids_are_unique_per_planet() -> void:
	var planet := _planet()
	var a := _site(planet)
	var b := _site(planet)
	assert_str(a.site_id()).is_not_equal(b.site_id())
	assert_str(a.site_id()).starts_with(planet.save_key() + "#")


func test_home_system_has_one_to_three_sites_per_planet_and_one_rich_per_moon() -> void:
	var state := (load("res://scenes/HomeSystem.tscn") as PackedScene).get_state()
	var planets := {}  # path -> {moon, gas}
	var sites := {}  # parent path -> [rich...]
	for i in state.get_node_count():
		var props := {}
		for p in state.get_node_property_count(i):
			props[state.get_node_property_name(i, p)] = state.get_node_property_value(i, p)
		var path := str(state.get_node_path(i)).trim_prefix("./")
		var parent := str(state.get_node_path(i, true)).trim_prefix("./")
		if state.get_node_instance(i) and props.has("planet_name"):
			planets[path] = {"moon": parent.count("/") >= 1, "type": props.get("planet_type", Planet.PlanetType.ROCKY)}
		elif props.get("script") and (props["script"] as Script).resource_path.ends_with("LandingSite.gd"):
			if not sites.has(parent):
				sites[parent] = []
			sites[parent].append(props.get("rich", false))
	assert_int(planets.size()).is_equal(11)  # sun + 5 planets + 5 moons
	for path in planets:
		var info: Dictionary = planets[path]
		var here: Array = sites.get(path, [])
		if info["type"] == Planet.PlanetType.SUN or info["type"] == Planet.PlanetType.GAS_GIANT:
			assert_array(here).is_empty()
		elif info["moon"]:
			assert_array(here).contains_exactly([true])
		else:
			assert_int(here.size()).is_between(1, 3)
			assert_array(here).not_contains([true])
