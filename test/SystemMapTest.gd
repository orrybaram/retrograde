extends GdUnitTestSuite

## The star chart: which regions it is allowed to draw at all, and the geometry helpers
## behind the drawing — what of a line or a ring actually crosses the view, so nothing
## is generated for the rest of it.

const CHART := Rect2(0, 0, 100, 100)

var _gs: GameState


func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	_gs.set_process(false)
	add_child(_gs)


func _planet(planet_name: String, parent: Node = null) -> Planet:
	var planet := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	planet.name = planet_name
	planet.radius = 400.0
	planet.enable_orbiting = false
	if parent:
		parent.add_child(planet)
	else:
		add_child(planet)
	for grown in planet.get_ore_deposits():
		grown.free()
	return planet

func test_segment_wholly_inside_is_untouched() -> void:
	var clipped := SystemMap._clip_segment(Vector2(10, 10), Vector2(90, 90), CHART)
	assert_int(clipped.size()).is_equal(2)
	assert_vector(clipped[0]).is_equal(Vector2(10, 10))
	assert_vector(clipped[1]).is_equal(Vector2(90, 90))

## The nav leg to a target off the chart still has to be drawn, cut at the edge.
func test_segment_running_off_the_chart_is_cut_at_the_edge() -> void:
	var clipped := SystemMap._clip_segment(Vector2(50, 50), Vector2(50, 9000), CHART)
	assert_int(clipped.size()).is_equal(2)
	assert_vector(clipped[0]).is_equal(Vector2(50, 50))
	assert_vector(clipped[1]).is_equal(Vector2(50, 100))

## Zoomed right in, both the ship and its target can be off chart with the leg
## crossing it: the visible stretch is what gets dashed.
func test_segment_crossing_with_both_ends_outside() -> void:
	var clipped := SystemMap._clip_segment(Vector2(-500, 50), Vector2(500, 50), CHART)
	assert_int(clipped.size()).is_equal(2)
	assert_vector(clipped[0]).is_equal(Vector2(0, 50))
	assert_vector(clipped[1]).is_equal(Vector2(100, 50))

func test_segment_missing_the_chart_is_dropped() -> void:
	assert_int(SystemMap._clip_segment(Vector2(-50, -50), Vector2(-10, 200), CHART).size()).is_equal(0)
	assert_int(SystemMap._clip_segment(Vector2(200, 10), Vector2(200, 90), CHART).size()).is_equal(0)

func test_zero_length_segment_inside_and_outside() -> void:
	assert_int(SystemMap._clip_segment(Vector2(50, 50), Vector2(50, 50), CHART).size()).is_equal(2)
	assert_int(SystemMap._clip_segment(Vector2(-5, 50), Vector2(-5, 50), CHART).size()).is_equal(0)

func test_arrival_radius_clears_a_planet_bulk() -> void:
	var planet: Planet = auto_free(Planet.new())
	planet.radius = 600.0
	assert_float(SystemMap._arrival_radius(planet)).is_equal(900.0)
	# Small bodies and stations keep the same short hop home base uses.
	planet.radius = 20.0
	assert_float(SystemMap._arrival_radius(planet)).is_equal(200.0)
	assert_float(SystemMap._arrival_radius(auto_free(Node2D.new()))).is_equal(200.0)


# --- Charted regions ---------------------------------------------------------

## The chart opens holding home and nothing else: the system is out there, but the
## Titan has not handed any of it over yet (docs/adr/0002).
func test_a_new_chart_holds_only_home() -> void:
	var sun := _planet("Sun")
	var veld := _planet("Veld", sun)
	var rook := _planet("Rook", veld)

	assert_bool(SystemMap.is_charted(rook, sun, rook, _gs)).is_true()
	assert_bool(SystemMap.is_charted(veld, sun, rook, _gs)).is_false()
	assert_bool(SystemMap.is_charted(sun, sun, rook, _gs)).is_false()


## Home is on the chart, but the orbit it rides round its planet is part of that
## planet's region and waits for the Gate like everything else.
func test_home_is_drawn_but_its_orbit_is_not() -> void:
	var sun := _planet("Sun")
	var veld := _planet("Veld", sun)
	var rook := _planet("Rook", veld)

	assert_bool(SystemMap.is_region_charted(rook, sun, _gs)).is_false()
	_gs.mark_gate_powered(veld.save_key())
	assert_bool(SystemMap.is_region_charted(rook, sun, _gs)).is_true()


## Powering one planet's Gate charts the whole region: the planet and its moons.
func test_powering_a_gate_charts_the_planet_and_its_moons() -> void:
	var sun := _planet("Sun")
	var crom := _planet("Crom", sun)
	var dross := _planet("Dross", crom)
	var veld := _planet("Veld", sun)

	_gs.mark_gate_powered(crom.save_key())

	assert_bool(SystemMap.is_charted(crom, sun, null, _gs)).is_true()
	assert_bool(SystemMap.is_charted(dross, sun, null, _gs)).is_true()
	# A neighbour with a dormant Gate stays off the chart.
	assert_bool(SystemMap.is_charted(veld, sun, null, _gs)).is_false()


## A moon is charted by its planet's Gate, never by one of its own.
func test_a_moon_belongs_to_its_planets_region() -> void:
	var sun := _planet("Sun")
	var veld := _planet("Veld", sun)
	var rook := _planet("Rook", veld)

	assert_object(SystemMap.region_planet(rook, sun)).is_same(veld)
	assert_object(SystemMap.region_planet(veld, sun)).is_same(veld)
	assert_object(SystemMap.region_planet(sun, sun)).is_same(sun)


## The sun holds the Core, whose Gate is the last thing to take power, so the middle of
## the chart stays empty however many Modules are online.
func test_the_sun_waits_for_its_own_gate() -> void:
	var sun := _planet("Sun")
	var veld := _planet("Veld", sun)
	_gs.mark_gate_powered(veld.save_key())

	assert_bool(SystemMap.is_charted(veld, sun, null, _gs)).is_true()
	assert_bool(SystemMap.is_charted(sun, sun, null, _gs)).is_false()
	_gs.mark_gate_powered(sun.save_key())
	assert_bool(SystemMap.is_charted(sun, sun, null, _gs)).is_true()


# --- Reveal ------------------------------------------------------------------

## A charted region draws itself in a piece at a time rather than switching on.
func test_a_region_arrives_piece_by_piece() -> void:
	assert_float(SystemMap._reveal_stage(0.0, SystemMap.Reveal.PLANET)).is_equal(0.0)
	# The planet is already on its way in before the Gate glyph has started.
	assert_bool(SystemMap._reveal_stage(SystemMap.REVEAL_STAGGER, SystemMap.Reveal.PLANET) > 0.0).is_true()
	assert_float(SystemMap._reveal_stage(SystemMap.REVEAL_STAGGER, SystemMap.Reveal.GATE)).is_equal(0.0)
	# By the end of the span every piece is fully drawn.
	assert_float(SystemMap._reveal_stage(SystemMap.REVEAL_SPAN, SystemMap.Reveal.GATE)).is_equal(1.0)
	assert_float(SystemMap._reveal_stage(SystemMap.REVEAL_SPAN, SystemMap.Reveal.PLANET)).is_equal(1.0)
