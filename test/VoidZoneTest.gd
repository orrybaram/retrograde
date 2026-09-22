extends GdUnitTestSuite

## Tests for the Void: where it starts, how fast its clock runs, and the hazard
## hatching the chart draws it with.


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_void_starts_clear_of_the_home_station() -> void:
	# Veld orbits at 253125 with e=0.06, Rook rides it at 20000 (e=0.04), and the
	# home station rides Rook at 6000 — so the dock itself reaches about 295000
	# from the sun. Start the void any closer and a normal run home ends in it.
	var station_reach := 253125.0 * 1.06 + 20000.0 * 1.04 + 6000.0
	assert_float(VoidZone.EDGE_RADIUS).is_greater(station_reach)
	assert_float(VoidZone.DEEP_RADIUS).is_greater(VoidZone.EDGE_RADIUS)


func test_depth_is_zero_inside_and_one_past_the_deep_radius() -> void:
	assert_float(VoidZone.depth_at(0.0)).is_equal(0.0)
	assert_float(VoidZone.depth_at(VoidZone.EDGE_RADIUS - 1.0)).is_equal(0.0)
	assert_float(VoidZone.depth_at(VoidZone.EDGE_RADIUS)).is_equal(0.0)
	assert_float(VoidZone.depth_at(VoidZone.DEEP_RADIUS)).is_equal(1.0)
	assert_float(VoidZone.depth_at(VoidZone.DEEP_RADIUS * 4.0)).is_equal(1.0)
	var middle := VoidZone.depth_at((VoidZone.EDGE_RADIUS + VoidZone.DEEP_RADIUS) / 2.0)
	assert_float(middle).is_between(0.49, 0.51)


func test_there_is_no_clock_the_fringe_never_takes_the_ship() -> void:
	# Loitering just past the edge is eerie, never fatal: only depth kills.
	assert_bool(VoidZone.consumes_at(VoidZone.depth_at(VoidZone.EDGE_RADIUS + 10.0))).is_false()
	assert_bool(VoidZone.consumes_at(VoidZone.depth_at(VoidZone.DEEP_RADIUS - 10.0))).is_false()


func test_the_deep_line_takes_the_ship() -> void:
	assert_bool(VoidZone.consumes_at(VoidZone.depth_at(VoidZone.DEEP_RADIUS))).is_true()
	assert_bool(VoidZone.consumes_at(VoidZone.depth_at(VoidZone.DEEP_RADIUS * 2.0))).is_true()


func test_the_dark_deepens_with_every_step_out() -> void:
	var previous := -1.0
	for step in 11:
		var d := VoidZone.depth_at(lerpf(VoidZone.EDGE_RADIUS, VoidZone.DEEP_RADIUS, step / 10.0))
		assert_float(d).is_greater(previous)
		previous = d


func test_taken_the_dark_holds_until_the_respawn() -> void:
	VoidZone.reset()
	VoidZone._taken = true
	VoidZone._relax(0.1)
	assert_float(VoidZone.shroud).is_equal(1.0)
	VoidZone.reset()
	VoidZone._relax(0.1)
	assert_float(VoidZone.shroud).is_equal(0.0)


# --- Chart hatching ----------------------------------------------------------

func _outside_segments(start: Vector2, direction: Vector2, length: float, center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	SystemMap._append_outside_circle(points, start, direction, length, center, radius)
	return points


func test_hatching_skips_lines_that_lie_inside_the_void_boundary() -> void:
	# A line right through the middle of a circle that swallows it: nothing to draw.
	var points := _outside_segments(Vector2(-10, 0), Vector2.RIGHT, 20.0, Vector2.ZERO, 500.0)
	assert_int(points.size()).is_equal(0)


func test_hatching_draws_whole_lines_that_miss_the_boundary() -> void:
	var points := _outside_segments(Vector2(0, 900), Vector2.RIGHT, 100.0, Vector2.ZERO, 500.0)
	assert_int(points.size()).is_equal(2)
	assert_vector(points[0]).is_equal(Vector2(0, 900))
	assert_vector(points[1]).is_equal(Vector2(100, 900))


func test_hatching_cuts_a_crossing_line_into_the_two_outside_pieces() -> void:
	# Straight through the middle, sticking out 100px either side of a r=500 circle.
	var points := _outside_segments(Vector2(-600, 0), Vector2.RIGHT, 1200.0, Vector2.ZERO, 500.0)
	assert_int(points.size()).is_equal(4)
	assert_vector(points[0]).is_equal(Vector2(-600, 0))
	assert_vector(points[1]).is_equal(Vector2(-500, 0))
	assert_vector(points[2]).is_equal(Vector2(500, 0))
	assert_vector(points[3]).is_equal(Vector2(600, 0))


func test_hatching_keeps_only_the_tail_when_a_line_starts_inside() -> void:
	var points := _outside_segments(Vector2.ZERO, Vector2.RIGHT, 900.0, Vector2.ZERO, 500.0)
	assert_int(points.size()).is_equal(2)
	assert_vector(points[0]).is_equal(Vector2(500, 0))
	assert_vector(points[1]).is_equal(Vector2(900, 0))


# --- Dashboard rot -----------------------------------------------------------

func test_corruption_keeps_the_length_and_the_spacing() -> void:
	var rng := _rng(7)
	var text := "150 / 50 CR"
	for i in 50:
		var rotted := HudGlitch.corrupt(text, 0.6, rng)
		assert_int(rotted.length()).is_equal(text.length())
		for c in text.length():
			if text[c] == " ":
				assert_str(rotted[c]).is_equal(" ")


func test_the_boundary_has_hysteresis_so_the_sky_cannot_strobe() -> void:
	var edge := VoidZone.EDGE_RADIUS
	# Flying out: the edge is the edge.
	assert_bool(VoidZone.inside_at(edge - 1.0, false)).is_false()
	assert_bool(VoidZone.inside_at(edge, false)).is_true()
	# Flying back in: still in the dark until there's real daylight behind you.
	# Both thresholds are inclusive, so the margin is the last point still inside.
	assert_bool(VoidZone.inside_at(edge - 1.0, true)).is_true()
	assert_bool(VoidZone.inside_at(edge - VoidZone.RE_ENTRY_MARGIN, true)).is_true()
	assert_bool(VoidZone.inside_at(edge - VoidZone.RE_ENTRY_MARGIN - 1.0, true)).is_false()


func test_a_ship_sitting_on_the_line_stays_in_one_state() -> void:
	# The exact failure hysteresis exists to prevent: jitter around the boundary
	# must not flip the state, or the warning fires over and over.
	var inside := false
	var flips := 0
	for i in 200:
		var was := inside
		inside = VoidZone.inside_at(VoidZone.EDGE_RADIUS - 200.0 + float(i % 3) * 100.0, inside)
		if inside != was:
			flips += 1
	# One crossing in, and then it holds. Without the margin this jitter would
	# flip on every third frame and radio the warning each time.
	assert_int(flips).is_equal(1)
	assert_bool(inside).is_true()


# --- The warning -------------------------------------------------------------

func test_the_edge_warning_goes_out_on_every_crossing() -> void:
	# It's the only warning for something that kills. A `once`
	# flag would spend it the first time — including on a crossing the player
	# never saw, because RobotRadio marks once-conversations seen when they are
	# merely queued, and a game over clears the queue.
	var conv := load("res://entities/Robot/radio/messages/void_edge.tres") as RadioConversation
	assert_bool(conv.once).is_false()
	assert_int(conv.priority).is_equal(RadioConversation.Priority.URGENT)
	assert_bool(conv.pause_game).is_false()  # you have to be able to fly out of it


# --- The last transmission ---------------------------------------------------

func test_the_game_over_call_never_gets_a_word_through() -> void:
	var conv := load("res://entities/Robot/radio/messages/void_consumed.tres") as RadioConversation
	assert_int(conv.lines.size()).is_greater(0)
	for line: RadioLine in conv.lines:
		assert_bool(line.garbled).override_failure_message(line.text).is_true()
		# Red face: RobotView paints `lost` in Colors.DANGER.
		assert_str(String(line.expression)).is_equal("lost")
		assert_str(line.display_text()).is_not_equal(line.text)
	# The confirm label is its own widget, so RELAUNCH still reads through the noise.
	assert_str(conv.lines[-1].confirm_text({"penalty": 30})).contains("RELAUNCH")


func test_scrambling_keeps_the_shape_of_speech() -> void:
	var source := "Stay inside the orbits and I'll stay talking."
	var noise := RadioLine.scramble(source)
	assert_int(noise.length()).is_equal(source.length())
	assert_str(noise).is_not_equal(source)
	for i in source.length():
		if source[i] == " ":
			assert_str(noise[i]).is_equal(" ")
		else:
			assert_bool(RobotFaces.GLITCH_CHARS.contains(noise[i])).is_true()


func test_a_garbled_line_still_reads_for_as_long_as_it_would_have() -> void:
	# read_time works off length, so garbling must not change how long it holds.
	var spoken := RadioLine.make("There's no wreck. There's no heat. There's no you.")
	var lost := RadioLine.make(spoken.text)
	lost.garbled = true
	assert_float(lost.read_time()).is_equal_approx(spoken.read_time(), 0.001)


func test_the_lost_face_is_a_real_face() -> void:
	assert_bool(RobotFaces.has_face(&"lost")).is_true()
	var rows := RobotFaces.rows_for(&"lost")
	assert_int(rows.size()).is_equal(RobotFaces.ROWS)
	for row in rows:
		assert_int(row.length()).is_equal(RobotFaces.WIDTH)


func test_nothing_rots_at_zero_and_everything_rots_at_one() -> void:
	var rng := _rng(11)
	assert_str(HudGlitch.corrupt("12.5 m/s", 0.0, rng)).is_equal("12.5 m/s")
	var gone := HudGlitch.corrupt("12.5", 1.0, rng)
	for c in gone.length():
		assert_bool(RobotFaces.GLITCH_CHARS.contains(gone[c])).is_true()
