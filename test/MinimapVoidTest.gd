extends GdUnitTestSuite

## The minimap hatches the Void the way the chart does, clipped to its own disc.

const DISC := 70.0

func test_no_hatching_well_inside_the_system() -> void:
	var sun := Vector2(0, 200)  # the edge is 800 px past the disc
	assert_array(Minimap.void_hatching(Vector2.ZERO, DISC, sun, 1000.0, 13.0, 0.0)).is_empty()

func test_the_whole_disc_is_hatched_out_in_the_void() -> void:
	var points := Minimap.void_hatching(Vector2.ZERO, DISC, Vector2(5000, 0), 1000.0, 13.0, 0.0)
	assert_int(points.size()).is_greater(10)
	for p in points:
		assert_float(p.length()).is_less_equal(DISC + 0.01)

func test_only_the_side_past_the_edge_is_hatched() -> void:
	# The edge runs straight down through the disc's middle; the Void is to the right
	var sun := Vector2(-1000, 0)
	var points := Minimap.void_hatching(Vector2.ZERO, DISC, sun, 1000.0, 13.0, 0.0)
	assert_int(points.size()).is_greater(0)
	for p in points:
		assert_float(p.distance_to(sun)).is_greater_equal(1000.0 - 0.5)
		assert_float(p.length()).is_less_equal(DISC + 0.01)
