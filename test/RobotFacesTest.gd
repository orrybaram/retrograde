extends GdUnitTestSuite

## Tests for the robot's ASCII face data and transforms.


func test_every_face_has_fixed_shape() -> void:
	for face in RobotFaces.names():
		var rows := RobotFaces.rows_for(face)
		assert_int(rows.size()).override_failure_message(String(face)).is_equal(RobotFaces.ROWS)
		for row in rows:
			assert_int(row.length()).override_failure_message(String(face)).is_equal(RobotFaces.WIDTH)


func test_talk_frames_fit_the_screen() -> void:
	for mouth in RobotFaces.TALK_MOUTHS:
		assert_int(mouth.length()).is_equal(RobotFaces.WIDTH)


func test_unknown_face_falls_back_to_neutral() -> void:
	assert_array(Array(RobotFaces.rows_for(&"nope"))).is_equal(Array(RobotFaces.rows_for(&"neutral")))


func test_blink_closes_eyes_only() -> void:
	var rows := RobotFaces.blink(RobotFaces.rows_for(&"neutral"))
	assert_str(rows[0]).is_equal(" -   - ")
	assert_str(rows[1]).is_equal(RobotFaces.rows_for(&"neutral")[1])


func test_talk_keeps_eyes_and_cycles_mouth() -> void:
	var happy := RobotFaces.rows_for(&"happy")
	var frame0 := RobotFaces.talk(happy, 0)
	var frame1 := RobotFaces.talk(happy, 1)
	assert_str(frame0[0]).is_equal(happy[0])
	assert_str(frame0[1]).is_not_equal(frame1[1])
	assert_str(RobotFaces.talk(happy, RobotFaces.TALK_MOUTHS.size())[1]).is_equal(frame0[1])


func test_corrupt_preserves_width_and_source() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var source := RobotFaces.rows_for(&"neutral")
	var noisy := RobotFaces.corrupt(source, rng, 1.0)
	assert_str(noisy[0]).is_not_equal(source[0])
	assert_str(source[0]).is_equal(" O   O ")
	for row in noisy:
		assert_int(row.length()).is_equal(RobotFaces.WIDTH)


func test_view_ignores_unknown_expression() -> void:
	var view := auto_free(RobotView.new()) as RobotView
	view.expression = &"bogus"
	assert_str(String(view.expression)).is_equal("neutral")
