extends GdUnitTestSuite

## Ordinary thrust tops out at the cruise cap; the boost and gravity can still go past it.

func test_thrust_accelerates_below_the_cap() -> void:
	var v := FlyingState.cruise_velocity(Vector2(100, 0), Vector2(5, 0), 300.0)
	assert_vector(v).is_equal(Vector2(105, 0))

func test_thrust_stops_at_the_cap() -> void:
	var v := FlyingState.cruise_velocity(Vector2(298, 0), Vector2(5, 0), 300.0)
	assert_vector(v).is_equal_approx(Vector2(300, 0), Vector2(0.001, 0.001))

func test_thrust_adds_nothing_at_the_cap() -> void:
	var v := FlyingState.cruise_velocity(Vector2(300, 0), Vector2(5, 0), 300.0)
	assert_float(v.length()).is_equal_approx(300.0, 0.001)

func test_braking_works_at_the_cap() -> void:
	var v := FlyingState.cruise_velocity(Vector2(300, 0), Vector2(-5, 0), 300.0)
	assert_vector(v).is_equal(Vector2(295, 0))

func test_steering_at_the_cap_turns_without_speeding_up() -> void:
	var v := FlyingState.cruise_velocity(Vector2(300, 0), Vector2(0, 5), 300.0)
	assert_float(v.length()).is_equal_approx(300.0, 0.001)
	assert_float(v.y).is_greater(0.0)

func test_above_the_cap_thrust_never_adds_speed() -> void:
	var v := FlyingState.cruise_velocity(Vector2(600, 0), Vector2(5, 0), 300.0)
	assert_float(v.length()).is_equal_approx(600.0, 0.001)

func test_above_the_cap_braking_still_slows() -> void:
	var v := FlyingState.cruise_velocity(Vector2(600, 0), Vector2(-5, 0), 300.0)
	assert_vector(v).is_equal(Vector2(595, 0))
