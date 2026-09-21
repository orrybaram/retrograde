extends GdUnitTestSuite

## Freight (docs/adr/0012): the magnet, the pose a Lug fixes, the release meter, and how
## a clamped load slows turning without touching unladen flight.

const NOSE := Vector2(10, 0)

# --- the magnet ---

func test_in_reach_of_the_magnet() -> void:
	assert_bool(Freight.in_reach(NOSE, NOSE + Vector2(20, 0))).is_true()

func test_out_of_reach_of_the_magnet() -> void:
	assert_bool(Freight.in_reach(NOSE, NOSE + Vector2(40, 0))).is_false()

func test_the_magnet_pulls_toward_the_pose() -> void:
	var m := Freight.magnet_motion(Vector2(50, 0), 0.0)
	assert_float((m[0] as Vector2).x).is_greater(0.0)
	assert_float((m[0] as Vector2).length()).is_less_equal(Freight.MAGNET_SPEED)

func test_the_magnet_turns_the_piece_into_place() -> void:
	var m := Freight.magnet_motion(Vector2.ZERO, 1.0)
	assert_float(m[1]).is_greater(0.0)
	assert_float(m[1]).is_less_equal(Freight.MAGNET_SPIN)

func test_the_magnet_never_creeps_the_last_few_pixels() -> void:
	var m := Freight.magnet_motion(Vector2(2, 0), 0.0)
	assert_float((m[0] as Vector2).length()).is_greater(1.0)

func test_seated_only_close_and_square() -> void:
	assert_bool(Freight.is_seated(Vector2(1, 0), 0.01)).is_true()
	assert_bool(Freight.is_seated(Vector2(10, 0), 0.01)).is_false()
	assert_bool(Freight.is_seated(Vector2(1, 0), 0.5)).is_false()

# --- releasing ---

func test_release_meter_fills() -> void:
	assert_str(CarryingState.release_meter(0.0)).is_equal("······")
	assert_str(CarryingState.release_meter(0.5)).is_equal("███···")
	assert_str(CarryingState.release_meter(1.0)).is_equal("██████")

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

# --- knocks ---

func test_bumping_freight_needs_a_very_fast_hit() -> void:
	var piece: Freight = auto_free(Freight.new())
	assert_float(FlyingState.knock_threshold(piece, 50.0)).is_equal(Freight.KNOCK_DAMAGE_SPEED)

func test_other_bodies_keep_the_ship_threshold() -> void:
	var rock: RigidBody2D = auto_free(RigidBody2D.new())
	assert_float(FlyingState.knock_threshold(rock, 50.0)).is_equal(50.0)

func test_release_label_reads_releasing() -> void:
	assert_str(CarryingState.release_label(0.5)).is_equal("RELEASING ███···")

# --- the Sweep ---

func test_a_ring_reaches_nearby_things_first() -> void:
	var near := SonarPulse.time_to_reach(30.0)
	var far := SonarPulse.time_to_reach(240.0)
	assert_float(near).is_greater_equal(0.0)
	assert_float(far).is_greater(near)
	assert_float(far).is_less_equal(SonarPulse.LIFETIME)

func test_a_ring_never_reaches_past_its_edge() -> void:
	assert_float(SonarPulse.time_to_reach(SonarPulse.END_RADIUS + 1.0)).is_equal(-1.0)

func test_freight_answers_a_sweep_at_its_lug() -> void:
	var piece: Freight = auto_free(Freight.new())
	add_child(piece)
	assert_bool(piece.is_in_group("sonar_listeners")).is_true()
	assert_vector(piece.sonar_point()).is_equal(piece.lug_global())
	piece.on_sonar_touched()
	assert_object(piece._lug_line.default_color).is_equal(Colors.TITAN)
	assert_int(piece._visual.get_children().filter(func(c): return c is SonarEcho).size()).is_equal(1)

func test_a_clamped_piece_still_lets_its_echo_fade() -> void:
	var piece: Freight = auto_free(Freight.new())
	add_child(piece)
	piece.on_sonar_touched()
	piece.process_mode = Node.PROCESS_MODE_DISABLED  # what clamping does
	await get_tree().create_timer(SonarEcho.LIFETIME + SonarEcho.STAGGER * SonarEcho.RINGS + 0.2).timeout
	assert_int(piece._visual.get_children().filter(func(c): return c is SonarEcho).size()).is_equal(0)
	assert_float(piece._lug_line.width).is_equal_approx(3.0, 0.01)

func test_clamping_lights_the_piece_up_and_it_settles_back() -> void:
	var piece: Freight = auto_free(Freight.new())
	add_child(piece)
	piece.flash_clamped()
	assert_that(piece._body.color).is_not_equal(Colors.HULL_MID)
	assert_that(piece._lug_line.default_color).is_equal(Colors.CREAM)
	piece.process_mode = Node.PROCESS_MODE_DISABLED  # clamped: the flash must still play out
	await get_tree().create_timer(Freight.CLAMP_FLASH_TIME * 1.4 + 0.2).timeout
	assert_that(piece._body.color).is_equal(Colors.HULL_MID)
	assert_float(piece._lug_line.width).is_equal_approx(3.0, 0.01)
