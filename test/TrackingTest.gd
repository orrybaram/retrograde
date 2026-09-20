extends GdUnitTestSuite

## Tests for the tracking system: solution math, targets, tracker and HUD helpers.


func test_solution_closing_straight_on() -> void:
	var s := TrackingSolution.solve(Vector2.ZERO, Vector2(50, 0), Vector2(1000, 0), Vector2.ZERO)
	assert_float(s.distance).is_equal(1000.0)
	assert_vector(s.direction).is_equal(Vector2.RIGHT)
	assert_float(s.closing_speed).is_equal(50.0)
	assert_float(s.drift_speed).is_equal(0.0)
	assert_float(s.eta).is_equal(20.0)
	assert_float(s.course_error()).is_equal_approx(0.0, 0.001)


func test_solution_moving_away_has_no_eta() -> void:
	var s := TrackingSolution.solve(Vector2.ZERO, Vector2(-30, 0), Vector2(500, 0), Vector2.ZERO)
	assert_float(s.closing_speed).is_equal(-30.0)
	assert_bool(is_inf(s.eta)).is_true()


func test_solution_uses_relative_velocity() -> void:
	# Chasing a target that moves away at the same speed: no closing, no drift.
	var s := TrackingSolution.solve(Vector2.ZERO, Vector2(40, 0), Vector2(300, 0), Vector2(40, 0))
	assert_float(s.closing_speed).is_equal(0.0)
	assert_bool(is_inf(s.eta)).is_true()


func test_solution_reports_sideways_drift() -> void:
	var s := TrackingSolution.solve(Vector2.ZERO, Vector2(0, 25), Vector2(400, 0), Vector2.ZERO)
	assert_float(s.closing_speed).is_equal_approx(0.0, 0.001)
	assert_float(absf(s.drift_speed)).is_equal_approx(25.0, 0.001)


func test_formatting() -> void:
	assert_str(TrackingSolution.format_distance(420.4)).is_equal("420 m")
	assert_str(TrackingSolution.format_distance(12345.0)).is_equal("12.3 km")
	assert_str(TrackingSolution.format_eta(75.0)).is_equal("1:15")
	assert_str(TrackingSolution.format_eta(INF)).is_equal("--:--")


func test_point_target() -> void:
	var t := PointTrackingTarget.new(Vector2(10, 20), "NAV-1")
	assert_str(t.get_label()).is_equal("NAV-1")
	assert_vector(t.get_position()).is_equal(Vector2(10, 20))
	assert_vector(t.get_velocity()).is_equal(Vector2.ZERO)
	assert_bool(t.is_valid()).is_true()


func test_node_target_reads_body_velocity_and_invalidates() -> void:
	var body := RigidBody2D.new()
	add_child(body)
	body.global_position = Vector2(5, 5)
	body.linear_velocity = Vector2(3, 4)
	var t := NodeTrackingTarget.new(body, "BODY")
	assert_bool(t.is_valid()).is_true()
	assert_vector(t.get_position()).is_equal(Vector2(5, 5))
	assert_vector(t.get_velocity()).is_equal(Vector2(3, 4))
	body.free()
	assert_bool(t.is_valid()).is_false()


func test_tracker_holds_one_target_and_drops_invalid() -> void:
	var tracker: Tracker = auto_free(Tracker.new())
	var changes := []
	tracker.target_changed.connect(func(t): changes.append(t))
	var node := Node2D.new()
	add_child(node)
	var a := NodeTrackingTarget.new(node, "A")
	var b := PointTrackingTarget.new(Vector2.ONE, "B")
	tracker.track(a)
	tracker.track(b)
	assert_object(tracker.target).is_same(b)
	tracker.track(a)
	node.free()
	assert_bool(tracker.has_target()).is_false()
	assert_array(changes).contains_exactly([a, b, a, null])
	assert_object(tracker.solve_from(Vector2.ZERO, Vector2.ZERO)).is_null()


func test_edge_point_hits_rect_border() -> void:
	var rect := Rect2(0, 0, 100, 50)
	var origin := Vector2(50, 25)
	assert_vector(TrackingIndicator.edge_point(rect, origin, Vector2.RIGHT)).is_equal(Vector2(100, 25))
	assert_vector(TrackingIndicator.edge_point(rect, origin, Vector2.UP)).is_equal(Vector2(50, 0))
	var diag := TrackingIndicator.edge_point(rect, origin, Vector2(1, 1).normalized())
	assert_vector(diag).is_equal_approx(Vector2(75, 50), Vector2(0.01, 0.01))


func test_readout_signs_closing_and_away() -> void:
	var closing := TrackingIndicator.readout_lines("HOME", TrackingSolution.solve(Vector2.ZERO, Vector2(20, 0), Vector2(200, 0), Vector2.ZERO))
	assert_array(Array(closing)).contains_exactly(["HOME  200 m", "+20 m/s", "DRIFT 0 m/s"])
	var away := TrackingIndicator.readout_lines("HOME", TrackingSolution.solve(Vector2.ZERO, Vector2(-20, 0), Vector2(200, 0), Vector2.ZERO))
	assert_str(away[1]).is_equal("-20 m/s")
	var holding := TrackingIndicator.readout_lines("HOME", TrackingSolution.solve(Vector2.ZERO, Vector2.ZERO, Vector2(200, 0), Vector2.ZERO))
	assert_str(holding[1]).is_equal("HOLD")


func test_push_out_of_blocker_moves_to_nearest_edge() -> void:
	var blocker: Array[Rect2] = [Rect2(0, 500, 300, 220)]
	# On the left screen edge, just inside the blocker: slides up above it.
	assert_vector(TrackingIndicator.push_out_of(Vector2(40, 520), blocker)).is_equal(Vector2(40, 500))
	# On the bottom edge near the blocker's right side: slides right.
	assert_vector(TrackingIndicator.push_out_of(Vector2(290, 680), blocker)).is_equal(Vector2(300, 680))
	# Outside: untouched.
	assert_vector(TrackingIndicator.push_out_of(Vector2(400, 680), blocker)).is_equal(Vector2(400, 680))


func test_push_rect_out_of_blocker_follows_shorter_slide() -> void:
	var blocker: Array[Rect2] = [Rect2(0, 500, 300, 220)]
	# Readout centred on a chevron just past the blocker's right side: slides right, not up.
	var near_right := TrackingIndicator.push_rect_out_of(Rect2(250, 600, 100, 40), blocker)
	assert_vector(near_right.position).is_equal(Vector2(300, 600))
	# Readout dipping into the blocker's top: slides up.
	var near_top := TrackingIndicator.push_rect_out_of(Rect2(40, 480, 100, 40), blocker)
	assert_vector(near_top.position).is_equal(Vector2(40, 460))
	# Clear of it: untouched.
	var clear := TrackingIndicator.push_rect_out_of(Rect2(400, 600, 100, 40), blocker)
	assert_vector(clear.position).is_equal(Vector2(400, 600))
