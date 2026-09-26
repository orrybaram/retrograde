extends GdUnitTestSuite

## Tests for the new-game intro: a few lines typed out before the boot terminal.


func test_it_names_the_system() -> void:
	assert_str(IntroScreen.LINES[0]).contains("KSD-78")


func test_it_stays_short() -> void:
	# A mood-setter, not a cutscene: the text is all up in a few seconds.
	assert_float(IntroScreen.typed_by()).is_less(9.0)


func test_only_the_cursor_shows_before_the_lead_in() -> void:
	assert_str(IntroScreen.text_at(0.0)).is_empty()
	assert_str(IntroScreen.text_at(IntroScreen.LEAD_IN - 0.01)).is_empty()


func test_the_first_line_types_out_a_character_at_a_time() -> void:
	var early := IntroScreen.text_at(IntroScreen.LEAD_IN + 0.2)
	assert_bool(IntroScreen.LINES[0].begins_with(early)).is_true()
	assert_int(early.length()).is_between(1, IntroScreen.LINES[0].length() - 1)


func test_both_lines_are_whole_by_the_end() -> void:
	var text := IntroScreen.text_at(IntroScreen.typed_by())
	assert_str(text).is_equal(IntroScreen.SEPARATOR.join(IntroScreen.LINES))


func test_the_cursor_waits_on_an_empty_second_line_before_typing() -> void:
	var first_done := IntroScreen.LINES[0]
	var dropped := IntroScreen._schedule()[1].x + 0.01
	assert_str(IntroScreen.text_at(dropped)).is_equal(first_done + IntroScreen.SEPARATOR)
	assert_bool(IntroScreen._is_typing(dropped)).is_false()


func test_the_last_line_holds_rather_than_moving_on() -> void:
	var long_after := IntroScreen.typed_by() + 60.0
	assert_str(IntroScreen.text_at(long_after)).is_equal(
		IntroScreen.SEPARATOR.join(IntroScreen.LINES))


func test_the_lines_never_say_what_happened() -> void:
	# SR-7's state is clued, never stated (docs/OPENING.md "Why it is broken").
	for line in IntroScreen.LINES:
		for word in ["sabotage", "clone", "destroy", "pilot"]:
			assert_str(line.to_lower()).not_contains(word)
