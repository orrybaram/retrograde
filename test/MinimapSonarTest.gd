extends GdUnitTestSuite

## The minimap is a sonar over a chart: planets, stations and Gates are charted and drawn
## steady; a beam sweeps the rest, what it crosses echoes and fades, and size is all that
## tells one echo from another.

func test_the_beam_goes_round_once_a_period() -> void:
	assert_float(Minimap.beam_angle(0.0)).is_equal_approx(0.0, 0.0001)
	assert_float(Minimap.beam_angle(Minimap.SWEEP_PERIOD * 0.25)).is_equal_approx(PI / 2.0, 0.0001)
	assert_float(Minimap.beam_angle(Minimap.SWEEP_PERIOD)).is_equal_approx(0.0, 0.0001)


func test_a_bearing_is_crossed_only_by_the_frame_that_sweeps_it() -> void:
	assert_bool(Minimap.beam_crossed(0.10, 0.20, 0.15)).is_true()
	assert_bool(Minimap.beam_crossed(0.10, 0.20, 0.25)).is_false()
	assert_bool(Minimap.beam_crossed(0.10, 0.20, 0.05)).is_false()
	# across the wrap
	assert_bool(Minimap.beam_crossed(TAU - 0.05, 0.05, 0.0)).is_true()


func test_an_echo_fades_to_the_floor_and_stays_there() -> void:
	assert_float(Minimap.glow(0.0)).is_equal_approx(1.0, 0.0001)
	assert_float(Minimap.glow(Minimap.AFTERGLOW * 0.5)).is_between(Minimap.AFTERGLOW_FLOOR, 1.0)
	assert_float(Minimap.glow(Minimap.AFTERGLOW)).is_equal_approx(Minimap.AFTERGLOW_FLOOR, 0.0001)
	assert_float(Minimap.glow(Minimap.AFTERGLOW * 3.0)).is_equal_approx(Minimap.AFTERGLOW_FLOOR, 0.0001)


class Sized extends MinimapTarget:
	var r := 0.0
	var body := false
	func _init(radius: float, is_a_body := false) -> void:
		r = radius
		body = is_a_body
	func echo_world_radius() -> float:
		return r
	func is_body() -> bool:
		return body


func test_echoes_are_to_scale_down_to_the_minimum() -> void:
	var map: Minimap = auto_free(Minimap.new())
	# Sizes below are picked against a long range, where most small things hit the minimum
	map.world_range = 10000.0
	assert_float(map.echo_radius(Sized.new(25.0))).is_equal(Minimap.ECHO_MIN_PX)
	assert_float(map.echo_radius(Sized.new(90.0))).is_equal(Minimap.ECHO_MIN_PX)
	var station := map.echo_radius(Sized.new(450.0))
	assert_float(station).is_greater(Minimap.ECHO_MIN_PX)
	var planet := map.echo_radius(Sized.new(1600.0, true))
	assert_float(planet).override_failure_message("planets are the biggest thing on the scope").is_greater(station * 3.0)


class Hidden extends MinimapTarget:
	var shown := false
	func is_minimap_visible() -> bool:
		return shown


func test_something_there_from_the_start_is_not_a_discovery() -> void:
	var map: Minimap = auto_free(Minimap.new())
	var planet := Sized.new(1600.0, true)
	map.register_target(planet)
	map.note_discoveries()
	assert_bool(map.is_undiscovered(planet)).is_false()


func test_something_that_turns_up_later_is_a_discovery() -> void:
	var map: Minimap = auto_free(Minimap.new())
	var scrap := Hidden.new()
	map.register_target(scrap)
	map.note_discoveries()
	assert_bool(map.is_undiscovered(scrap)).override_failure_message("hidden: nothing to discover yet").is_false()
	scrap.shown = true
	map.note_discoveries()
	assert_bool(map.is_undiscovered(scrap)).override_failure_message("revealed: its first echo will ping").is_true()


func test_home_is_the_one_diamond() -> void:
	assert_bool(MinimapTarget.new().echo_is_diamond()).is_false()
	var station: SpaceStation = auto_free(load("res://entities/structures/SpaceStation.tscn").instantiate())
	assert_bool(SpaceStationMinimapTarget.new(station).echo_is_diamond()).is_true()


func test_planets_stations_and_gates_are_charted_not_swept() -> void:
	assert_bool(MinimapTarget.new().is_charted()).is_false()
	assert_bool(PlanetMinimapTarget.new(null).is_charted()).is_true()
	assert_bool(SpaceStationMinimapTarget.new(null).is_charted()).is_true()
	assert_bool(GateMinimapTarget.new(null).is_charted()).is_true()
	assert_bool(ResourceMinimapTarget.new(null).is_charted()).is_false()
	assert_bool(DebrisMinimapTarget.new(null).is_charted()).is_false()


## The beam meets a planet at the near face of its outline, not its centre.
func test_a_planet_returns_from_the_face_toward_the_ship() -> void:
	var map: Minimap = auto_free(Minimap.new())
	map.ship = auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	map.ship.position = Vector2.ZERO
	var center := Vector2(80, 80)
	# A body 40 px right of the ship on the scope, 10 px in radius
	var world := Vector2(40.0 / map.display_radius * map.world_range, 0.0)
	var at: Vector2 = map._body_return_point(center, world, 10.0, 0.0)
	assert_vector(at).is_equal_approx(center + Vector2(30, 0), Vector2(0.01, 0.01))
	# Off the scope altogether: no return
	assert_object(map._body_return_point(center, world * 10.0, 10.0, 0.0)).is_null()


## A station is charted as one outline: its major pieces merged into a few contours, not
## a shape per crate.
func test_a_station_charts_as_a_merged_outline() -> void:
	var station: SpaceStation = auto_free(load("res://entities/structures/SpaceStation.tscn").instantiate())
	add_child(station)
	var outline := SpaceStationMinimapTarget.new(station).chart_outline()
	assert_int(outline.size()).is_between(1, 4)
	for contour in outline:
		assert_int(contour.size()).is_greater_equal(3)
