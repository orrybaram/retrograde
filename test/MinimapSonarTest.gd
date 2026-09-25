extends GdUnitTestSuite

## The minimap is a sonar: a beam sweeps it, what it crosses echoes and fades, and size is
## all that tells one echo from another.

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
