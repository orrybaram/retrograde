extends GdUnitTestSuite

## Freight (docs/adr/0012): the docking-style clamp checks, the pose a Lug fixes, and how
## a clamped load slows turning without touching unladen flight.

const NOSE := Vector2(10, 0)

# --- clamping ---

func test_clamps_nose_in_slow_and_close() -> void:
	assert_bool(Freight.can_clamp(NOSE, Vector2.RIGHT, Vector2.ZERO, NOSE + Vector2(6, 0), Vector2.LEFT)).is_true()

func test_too_far_from_the_lug() -> void:
	assert_bool(Freight.can_clamp(NOSE, Vector2.RIGHT, Vector2.ZERO, NOSE + Vector2(40, 0), Vector2.LEFT)).is_false()

func test_too_fast() -> void:
	assert_bool(Freight.can_clamp(NOSE, Vector2.RIGHT, Vector2(60, 0), NOSE + Vector2(6, 0), Vector2.LEFT)).is_false()

func test_within_thirty_degrees_of_nose_in() -> void:
	var facing := Vector2.LEFT.rotated(deg_to_rad(25))
	assert_bool(Freight.can_clamp(NOSE, Vector2.RIGHT, Vector2.ZERO, NOSE + Vector2(6, 0), facing)).is_true()

func test_not_side_on() -> void:
	assert_bool(Freight.can_clamp(NOSE, Vector2.RIGHT, Vector2.ZERO, NOSE + Vector2(6, 0), Vector2.UP)).is_false()

func test_not_from_behind_the_lug() -> void:
	assert_bool(Freight.can_clamp(NOSE, Vector2.RIGHT, Vector2.ZERO, NOSE + Vector2(6, 0), Vector2.RIGHT)).is_false()

func test_pose_puts_the_lug_on_the_nose_facing_back() -> void:
	var lug := Vector2(-40, 0)
	var facing := Vector2.UP
	var pose := Freight.clamped_pose(lug, facing, NOSE)
	assert_vector(pose * lug).is_equal_approx(NOSE, Vector2(0.001, 0.001))
	assert_vector(pose.basis_xform(facing)).is_equal_approx(Vector2.LEFT, Vector2(0.001, 0.001))

# --- turning ---

func test_unladen_turn_is_unchanged() -> void:
	assert_float(FlyingState.turned_spin(0.0, 1.0, 5.0, 1.0, 1.0 / 60.0)).is_equal(5.0)
	assert_float(FlyingState.turned_spin(0.0, -1.0, 5.0, 1.0, 1.0 / 60.0)).is_equal(-5.0)

func test_unladen_stops_the_instant_the_key_is_up() -> void:
	assert_float(FlyingState.turned_spin(5.0, 0.0, 5.0, 1.0, 1.0 / 60.0)).is_equal(0.0)

func test_loaded_turn_winds_up_to_a_slower_rate() -> void:
	var spin := 0.0
	spin = FlyingState.turned_spin(spin, 1.0, 5.0, 0.5, 1.0 / 60.0)
	assert_float(spin).is_greater(0.0)
	assert_float(spin).is_less(2.5)
	for i in 120:
		spin = FlyingState.turned_spin(spin, 1.0, 5.0, 0.5, 1.0 / 60.0)
	assert_float(spin).is_equal_approx(2.5, 0.001)

func test_loaded_turn_carries_on_after_the_key_is_up() -> void:
	var spin := FlyingState.turned_spin(2.5, 0.0, 5.0, 0.5, 1.0 / 60.0)
	assert_float(spin).is_greater(0.0)

func test_no_load_keeps_the_whole_turn() -> void:
	assert_float(Ship.turn_ratio_for(200.0, 200.0)).is_equal(1.0)

func test_a_heavier_load_turns_worse() -> void:
	var light := Ship.turn_ratio_for(200.0, 800.0)
	var heavy := Ship.turn_ratio_for(200.0, 5000.0)
	assert_float(light).is_less(1.0)
	assert_float(heavy).is_less(light)

func test_a_long_piece_has_more_inertia_than_a_short_one() -> void:
	var long := PackedVector2Array([Vector2(-40, -6), Vector2(40, 6)])
	var short := PackedVector2Array([Vector2(-10, -6), Vector2(10, 6)])
	assert_float(Freight.box_inertia(long, 3.0)).is_greater(Freight.box_inertia(short, 3.0))
