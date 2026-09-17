extends GdUnitTestSuite

## Tests for the hold-and-release harvest timing model.

const G := HarvestTiming.Grade


func _timing(trophy := false, seed := 1) -> HarvestTiming:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return HarvestTiming.new(rng, trophy)


func _hold_to(t: HarvestTiming, target: float) -> void:
	t.progress = target


func test_zone_stays_inside_the_bar() -> void:
	for s in 200:
		var t := _timing(s % 2 == 0, s)
		assert_float(t.zone_start).is_greater_equal(HarvestTiming.ZONE_MIN_START)
		assert_float(t.zone_end).is_less(1.0)
		assert_float(t.perfect_start()).is_greater(t.zone_start)
		assert_float(t.perfect_end()).is_less(t.zone_end)


func test_trophy_is_slower_and_tighter() -> void:
	var normal := _timing(false)
	var trophy := _timing(true)
	assert_float(trophy.duration).is_greater(normal.duration)
	assert_float(trophy.zone_end - trophy.zone_start).is_less(normal.zone_end - normal.zone_start)


func test_hold_advances_by_duration() -> void:
	var t := _timing()
	assert_int(t.hold(t.duration / 4.0)).is_equal(G.NONE)
	assert_float(t.progress).is_equal_approx(0.25, 0.0001)


func test_holding_to_the_end_overloads() -> void:
	var t := _timing()
	assert_int(t.hold(t.duration * 2.0)).is_equal(G.OVERLOAD)
	assert_float(t.progress).is_equal(1.0)


func test_release_grades() -> void:
	var t := _timing()
	_hold_to(t, t.zone_start - 0.01)
	assert_int(t.release()).is_equal(G.EARLY)
	_hold_to(t, t.zone_start + 0.001)
	assert_int(t.release()).is_equal(G.GOOD)
	_hold_to(t, (t.perfect_start() + t.perfect_end()) / 2.0)
	assert_int(t.release()).is_equal(G.PERFECT)
	_hold_to(t, t.zone_end + 0.01)
	assert_int(t.release()).is_equal(G.LATE)


func test_in_zone_helpers() -> void:
	var t := _timing()
	_hold_to(t, t.perfect_start())
	assert_bool(t.in_zone()).is_true()
	assert_bool(t.in_perfect()).is_true()
	_hold_to(t, t.zone_start)
	assert_bool(t.in_zone()).is_true()
	assert_bool(t.in_perfect()).is_false()


func test_decay_drains_progress_but_not_below_zero() -> void:
	var t := _timing()
	_hold_to(t, 0.1)
	t.decay(0.1)
	assert_float(t.progress).is_less(0.1)
	t.decay(100.0)
	assert_float(t.progress).is_equal(0.0)


func test_grade_rolls() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 300:
		assert_int(TierData.roll_for_grade(G.OVERLOAD, false, rng)).is_equal(TierData.Tier.SLAG)
		assert_int(TierData.roll_for_grade(G.LATE, true, rng)).is_equal(TierData.Tier.SLAG)
		assert_int(TierData.roll_for_grade(G.GOOD, false, rng)).is_greater_equal(TierData.Tier.SCRAP)
		assert_int(TierData.roll_for_grade(G.GOOD, true, rng)).is_greater_equal(TierData.Tier.SALVAGE)
		assert_int(TierData.roll_for_grade(G.PERFECT, false, rng)).is_greater_equal(TierData.Tier.SALVAGE)
		assert_int(TierData.roll_for_grade(G.PERFECT, true, rng)).is_greater_equal(TierData.Tier.SALVAGE)


func test_perfect_trophy_rolls_skew_higher_than_good() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var good := 0
	var perfect := 0
	for i in 2000:
		good += TierData.roll_for_grade(G.GOOD, true, rng)
		perfect += TierData.roll_for_grade(G.PERFECT, true, rng)
	assert_int(perfect).is_greater(good)
