extends GdUnitTestSuite

## Procedures and the ship's side of them (docs/SWEEP.md): ProcedureDef matching, the
## Slots a hold lands in, the Commit, and the chaining window.

const CORE: ProcedureDef = preload("res://entities/procedure/sr7_core.tres")


func test_the_core_placard_is_seat_one_cycle_one() -> void:
	assert_array(CORE.marks()).is_equal([1, 1, 2, 1])
	assert_str(CORE.glyph(0)).is_equal("<seat>")
	assert_str(CORE.glyph(1)).is_equal("-1")
	assert_str(CORE.glyph(2)).is_equal("<cycle>")


func test_check_counts_right_marks_but_never_says_which() -> void:
	assert_bool(CORE.check([1, 1, 2, 1]).ok).is_true()
	var near := CORE.check([1, 1, 1, 1])
	assert_bool(near.ok).is_false()
	assert_int(near.right).is_equal(3)
	assert_bool(CORE.check([1, 1, 2]).incomplete).is_true()
	assert_bool(CORE.check([1, 1, 2, 1, 1, 1]).ok).override_failure_message("extra words are wrong").is_false()
	assert_bool(CORE.check([]).ok).is_false()


func test_a_tap_is_slot_one_and_the_bar_is_six_slots() -> void:
	var slot := Resonance.BAR_TIME / Resonance.SLOTS
	assert_int(Resonance.slot_for(0.0)).is_equal(1)
	assert_int(Resonance.slot_for(0.1)).is_equal(1)
	assert_int(Resonance.slot_for(slot * 1.5)).is_equal(2)
	assert_int(Resonance.slot_for(slot * 5.5)).is_equal(6)
	assert_bool(Resonance.is_commit(Resonance.BAR_TIME - 0.01)).is_false()
	assert_bool(Resonance.is_commit(Resonance.BAR_TIME)).is_true()


func test_a_commit_reaches_further_than_the_bar_shows() -> void:
	# Held to the end of the bar, the ring must reach anything close enough to show it
	var reach := SonarPulse.END_RADIUS * SonarPulse.strength_for(Resonance.BAR_TIME)
	assert_float(reach).is_greater(Resonance.REACH)


func test_marks_build_up_and_a_commit_carries_them_out() -> void:
	var r: Resonance = auto_free(Resonance.new())
	assert_array(r.release(0.1)).is_empty()
	assert_array(r.release(0.1)).is_empty()
	assert_array(r.release(0.4)).is_empty()
	assert_array(r.release(0.1)).is_empty()
	assert_array(r.marks).is_equal([1, 1, 2, 1])
	assert_array(r.release(Resonance.BAR_TIME + 0.2)).is_equal([1, 1, 2, 1])
	assert_array(r.marks).is_empty()
	assert_array(r.release(Resonance.BAR_TIME + 0.2)).override_failure_message("a Commit with nothing laid down carries nothing").is_empty()


func test_marks_fall_off_when_the_window_lapses_but_not_while_held() -> void:
	var r: Resonance = auto_free(Resonance.new())
	r.release(0.1)
	r.tick(Resonance.CHAIN_WINDOW * 0.5, false, true)
	assert_array(r.marks).is_equal([1])
	# Holding the next one - even a whole Commit - never lapses
	r.tick(Resonance.BAR_TIME * 2.0, true, true)
	assert_array(r.marks).is_equal([1])
	r.tick(Resonance.CHAIN_WINDOW, false, true)
	assert_array(r.marks).is_empty()


func test_marks_fall_off_out_of_reach() -> void:
	var r: Resonance = auto_free(Resonance.new())
	r.release(0.1)
	r.tick(0.016, true, false)
	assert_array(r.marks).is_empty()
