extends GdUnitTestSuite

## Geometry helpers behind the star chart's drawing: what of a line or a ring
## actually crosses the view, so nothing is generated for the rest of it.

const CHART := Rect2(0, 0, 100, 100)

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
