extends GdUnitTestSuite

## Tests for GemData: tier lookups, per-hit drops, and hold value.

const G := HarvestTiming.Grade


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_bigger_gems_are_worth_more_and_take_more_space() -> void:
	var prev_value := 0
	var prev_space := 0
	for tier in GemData.Tier.values():
		var id := GemData.item_id(tier)
		assert_int(GemData.value_of(id)).is_greater(prev_value)
		assert_int(GemData.space_of(id)).is_greater_equal(prev_space)
		prev_value = GemData.value_of(id)
		prev_space = GemData.space_of(id)
	assert_int(GemData.space_of("crystal")).is_greater(GemData.space_of("shard"))


func test_unknown_id_is_worthless() -> void:
	assert_int(GemData.value_of("slag")).is_equal(0)
	assert_bool(GemData.is_gem("slag")).is_false()
	assert_bool(GemData.is_gem("shard")).is_true()


func test_chip_hit_drops_one_to_three_gems() -> void:
	var rng := _rng(1)
	for i in 500:
		var n := GemData.drops_for_hit(G.GOOD, false, false, rng).size()
		assert_int(n).is_between(GemData.CHIP_MIN, GemData.CHIP_MAX)


func test_perfect_chip_adds_a_gem() -> void:
	var rng := _rng(2)
	for i in 500:
		var n := GemData.drops_for_hit(G.PERFECT, false, false, rng).size()
		assert_int(n).is_between(GemData.CHIP_MIN + 1, GemData.CHIP_MAX + 1)


func test_final_hit_drops_a_bigger_burst() -> void:
	var rng := _rng(3)
	for i in 500:
		var n := GemData.drops_for_hit(G.GOOD, true, false, rng).size()
		assert_int(n).is_between(GemData.BREAK_MIN, GemData.BREAK_MAX)
		var trophy_n := GemData.drops_for_hit(G.GOOD, true, true, rng).size()
		assert_int(trophy_n).is_greater_equal(GemData.BREAK_MIN + GemData.TROPHY_BREAK_BONUS)


func test_botched_hits_drop_only_shards() -> void:
	var rng := _rng(4)
	for i in 300:
		for grade in [G.LATE, G.OVERLOAD]:
			for id in GemData.drops_for_hit(grade, i % 2 == 0, true, rng):
				assert_str(id).is_equal("shard")


func test_perfect_rolls_are_worth_more_than_good() -> void:
	var rng := _rng(5)
	var good := 0
	var perfect := 0
	for i in 2000:
		good += GemData.value_of(GemData.roll(G.GOOD, false, rng))
		perfect += GemData.value_of(GemData.roll(G.PERFECT, false, rng))
	assert_int(perfect).is_greater(good)


func test_trophy_rolls_never_shard_on_clean_hits() -> void:
	var rng := _rng(6)
	for i in 1000:
		assert_str(GemData.roll(G.GOOD, true, rng)).is_not_equal("shard")
		assert_str(GemData.roll(G.PERFECT, true, rng)).is_not_equal("shard")


func test_hold_value_sums_quantities() -> void:
	var items := {"shard": 3, "crystal": 2, "slag": 9}
	var expected := 3 * GemData.value_of("shard") + 2 * GemData.value_of("crystal")
	assert_int(GemData.hold_value(items)).is_equal(expected)


func test_best_of_picks_highest_tier() -> void:
	assert_str(GemData.best_of(["shard", "crystal", "gem"])).is_equal("crystal")
	assert_str(GemData.best_of([])).is_equal("")
