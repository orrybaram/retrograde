extends GdUnitTestSuite

## Tests for the Planetary Scanner: scan meter fill/reset, planet selection, the
## survey readout, the upgrade unlock and the scanned-planet save round trip.

const SAVE_FILE := "user://scan_test_save.cfg"

var _gs: GameState


func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	add_child(_gs)


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))


func _planet(pos: Vector2, radius := 100.0, type := Planet.PlanetType.ROCKY) -> Planet:
	var planet := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	planet.radius = radius
	planet.planet_type = type
	add_child(planet)
	planet.global_position = pos
	return planet


func test_meter_fills_over_scan_time_and_completes_once() -> void:
	var planet := _planet(Vector2.ZERO)
	var scan := PlanetScan.new()
	assert_bool(scan.update(planet, PlanetScan.SCAN_TIME * 0.5)).is_false()
	assert_float(scan.progress).is_equal_approx(0.5, 0.001)
	assert_object(scan.target).is_same(planet)
	assert_bool(scan.update(planet, PlanetScan.SCAN_TIME * 0.5)).is_true()
	assert_float(scan.progress).is_equal(0.0)
	assert_object(scan.target).is_null()


func test_leaving_the_field_resets_the_meter() -> void:
	var planet := _planet(Vector2.ZERO)
	var scan := PlanetScan.new()
	scan.update(planet, PlanetScan.SCAN_TIME * 0.9)
	assert_bool(scan.update(null, 0.1)).is_false()
	assert_float(scan.progress).is_equal(0.0)
	scan.update(planet, 0.1)
	assert_float(scan.progress).is_equal_approx(0.1 / PlanetScan.SCAN_TIME, 0.001)


func test_switching_planets_restarts_the_meter() -> void:
	var a := _planet(Vector2.ZERO)
	var b := _planet(Vector2(5000, 0))
	var scan := PlanetScan.new()
	scan.update(a, PlanetScan.SCAN_TIME * 0.8)
	assert_bool(scan.update(b, 0.0)).is_false()
	assert_object(scan.target).is_same(b)
	assert_float(scan.progress).is_equal(0.0)


func test_pick_only_reaches_inner_orbit() -> void:
	var planet := _planet(Vector2.ZERO, 100.0)
	var inner := planet.scan_radius()
	assert_float(inner).is_greater(planet.radius)
	assert_float(inner).is_less(planet.field_radius())
	assert_object(PlanetScan.pick(Vector2(inner - 1.0, 0), [planet])).is_same(planet)
	assert_object(PlanetScan.pick(Vector2(inner + 1.0, 0), [planet])).is_null()
	# Being inside the gravity field is not enough
	assert_object(PlanetScan.pick(Vector2(planet.field_radius() - 1.0, 0), [planet])).is_null()


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


func test_pick_prefers_the_deeper_field_and_skips_scanned() -> void:
	var big := _planet(Vector2(1000, 0), 400.0)
	var moon := _planet(Vector2(1300, 0), 50.0)
	var ship_pos := Vector2(1310, 0)
	assert_object(PlanetScan.pick(ship_pos, [big, moon])).is_same(moon)
	_gs.mark_planet_scanned(moon.save_key())
	assert_object(PlanetScan.pick(ship_pos, [big, moon])).is_same(big)
	_gs.mark_planet_scanned(big.save_key())
	assert_object(PlanetScan.pick(ship_pos, [big, moon])).is_null()


## The sun is a Body like any other: it is surveyed by the same rule, and its survey
## honestly reports no ore (CONTEXT.md, Body; docs/adr/0003).
func test_the_sun_is_surveyed_like_any_other_body() -> void:
	var sun := _planet(Vector2.ZERO, 5000.0, Planet.PlanetType.SUN)
	sun.planet_name = "Sun"
	var inner := sun.scan_radius()
	assert_object(PlanetScan.pick(Vector2(inner - 1.0, 0), [sun])).is_same(sun)
	assert_object(PlanetScan.pick(Vector2(inner + 1.0, 0), [sun])).is_null()
	_gs.mark_planet_scanned(sun.save_key())
	assert_object(PlanetScan.pick(Vector2(inner - 1.0, 0), [sun])).is_null()
	assert_str("\n".join(PlanetScan.readout_lines(sun))).contains("NONE FOUND")


## pick() is deepest() plus the unscanned filter; deepest() itself keeps no such book.
func test_deepest_ignores_whether_a_body_is_scanned() -> void:
	var planet := _planet(Vector2.ZERO, 100.0)
	var pos := Vector2(planet.scan_radius() - 1.0, 0)
	assert_object(PlanetScan.deepest(pos, [planet])).is_same(planet)
	_gs.mark_planet_scanned(planet.save_key())
	assert_object(PlanetScan.deepest(pos, [planet])).is_same(planet)
	assert_object(PlanetScan.pick(pos, [planet])).is_null()


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


func test_meter_text_shows_unknown_target_and_fill() -> void:
	var text := ScanPanel.meter_text(0.5)
	assert_str(text).contains(ScanPanel.UNKNOWN)
	assert_str(text).contains("[########--------]")
	assert_str(text).contains("50%")


func test_scanner_upgrade_unlocks_the_feature() -> void:
	var item := load("res://entities/Upgrades/items/PlanetScanner_1.tres") as UpgradeItem
	assert_str(item.upgrade_path).is_equal("planet_scanner")
	assert_int(item.tier).is_equal(1)
	assert_int(item.effect_type).is_equal(UpgradeItem.EffectType.UNLOCK_FEATURE)
	assert_bool(_gs.has_planet_scanner).is_false()
	item.apply(null, _gs)
	assert_bool(_gs.has_planet_scanner).is_true()
	assert_int(_gs.get_upgrade_level("planet_scanner")).is_equal(1)


func test_scanner_is_sold_at_the_home_store() -> void:
	var store := load("res://entities/Store/SR7Store.tres") as StoreData
	var paths := store.upgrades.map(func(u: UpgradeItem): return u.upgrade_path)
	assert_array(paths).contains(["planet_scanner"])


func test_new_game_forgets_scans_and_the_scanner() -> void:
	_gs.has_planet_scanner = true
	_gs.mark_planet_scanned("Veld/Rook")
	_gs.reset_all_state()
	assert_bool(_gs.has_planet_scanner).is_false()
	assert_bool(_gs.is_planet_scanned("Veld/Rook")).is_false()


func test_scanned_planets_round_trip_through_the_save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "credits", 12)
	cfg.save(SAVE_FILE)
	Save.save_scanned_planets(PackedStringArray(["Veld/Rook", "Crom"]), SAVE_FILE)
	assert_array(Array(Save.load_scanned_planets(SAVE_FILE))).contains_exactly(["Veld/Rook", "Crom"])
	cfg.load(SAVE_FILE)
	assert_int(cfg.get_value("stats", "credits")).is_equal(12)


func test_scan_save_needs_an_existing_save() -> void:
	Save.save_scanned_planets(PackedStringArray(["Crom"]), SAVE_FILE)
	assert_bool(FileAccess.file_exists(SAVE_FILE)).is_false()
	assert_int(Save.load_scanned_planets(SAVE_FILE).size()).is_equal(0)
