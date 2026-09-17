extends GdUnitTestSuite

## Tests for TierData weighted rolls and lookups.


func test_roll_tier_never_returns_slag() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 1000:
		assert_int(TierData.roll_tier(rng)).is_not_equal(TierData.Tier.SLAG)


func test_roll_tier_only_returns_weighted_tiers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for i in 1000:
		assert_bool(TierData.ROLL_WEIGHTS.has(TierData.roll_tier(rng))).is_true()


func test_roll_tier_trophy_is_at_least_salvage() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 1000:
		assert_int(TierData.roll_tier_trophy(rng)).is_greater_equal(TierData.Tier.SALVAGE)


func test_roll_tier_distribution_matches_weights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var counts := {}
	var samples := 20000
	for i in samples:
		var tier := TierData.roll_tier(rng)
		counts[tier] = counts.get(tier, 0) + 1

	var total_weight := 0
	for w in TierData.ROLL_WEIGHTS.values():
		total_weight += w
	for tier in TierData.ROLL_WEIGHTS:
		var expected := float(TierData.ROLL_WEIGHTS[tier]) / total_weight
		var actual := float(counts.get(tier, 0)) / samples
		assert_float(actual).is_equal_approx(expected, 0.02)


func test_get_display_name_for_item_id() -> void:
	assert_str(TierData.get_display_name_for_item_id("mil_spec")).is_equal("Mil-Spec")


func test_get_display_name_for_unknown_item_id_capitalizes() -> void:
	assert_str(TierData.get_display_name_for_item_id("fuel_cell")).is_equal("Fuel Cell")


func test_tier_prices_match_economy() -> void:
	for tier in TierData.TIERS:
		var data: Dictionary = TierData.TIERS[tier]
		assert_int(Economy.get_resource_price(data["item_id"])).is_equal(data["price"])
