extends GdUnitTestSuite

## Tests for working an ore seam, which uses the same hold-and-release harvest as a scrap
## node: the gem tiers a seam rolls, the hit sequence, early release, overload, lifting
## off mid-sweep, and gems reaching the hold.

const GOOD := HarvestTiming.Grade.GOOD
const PERFECT := HarvestTiming.Grade.PERFECT
const LATE := HarvestTiming.Grade.LATE
const OVERLOAD := HarvestTiming.Grade.OVERLOAD

var _gs: GameState
var _hits: Array = []

func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	add_child(_gs)
	_hits.clear()
	InventoryManager.clear_inventory()

func after_test() -> void:
	InventoryManager.clear_inventory()
	Gem.clear_all()

func _seeded(seed_value := 7) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _mean_tier(rich: bool) -> float:
	var rng := _seeded(3 if rich else 4)
	var total := 0
	for i in 2000:
		total += GemData.tier_of(GemData.ore_roll(GOOD, rich, rng))
	return total / 2000.0

## Credits from breaking one seam open: every hit GOOD, the last one the break.
func _seam_value(rich: bool, rng: RandomNumberGenerator) -> int:
	var hits := OreDeposit.RICH_HITS if rich else OreDeposit.HITS
	var ids: Array[String] = []
	for hit in hits:
		ids.append_array(GemData.ore_drops(GOOD, hit == hits - 1, rich, rng))
	return GemData.hold_value(_as_hold(ids))

## Credits from breaking one scrap node: three hits, the last one the break, all GOOD.
func _scrap_value(rng: RandomNumberGenerator) -> int:
	var ids: Array[String] = []
	for hit in 3:
		ids.append_array(GemData.drops_for_hit(GOOD, hit == 2, false, rng))
	return GemData.hold_value(_as_hold(ids))

func _as_hold(ids: Array[String]) -> Dictionary:
	var hold := {}
	for id in ids:
		hold[id] = hold.get(id, 0) + 1
	return hold

func test_a_seam_pays_far_better_than_a_scrap_node() -> void:
	var rng := _seeded(3)
	var seam := 0
	var scrap := 0
	for i in 200:
		seam += _seam_value(false, rng)
		scrap += _scrap_value(rng)
	# A plain seam is worth several scrap nodes, and a rich moon seam far more again
	assert_float(float(seam) / float(scrap)).is_greater(1.8)
	var rich := 0
	for i in 200:
		rich += _seam_value(true, rng)
	assert_float(float(rich) / float(seam)).is_greater(2.0)

func test_rich_seams_roll_better_gems() -> void:
	assert_float(_mean_tier(true)).is_greater(_mean_tier(false))

func test_perfect_bumps_the_best_gem_of_the_hit() -> void:
	assert_array(GemData.bump_best(["shard", "gem", "shard"])).is_equal(["shard", "crystal", "shard"])
	assert_array(GemData.bump_best(["crystal", "artifact"])).is_equal(["crystal", "artifact"])
	assert_array(GemData.bump_best([])).is_empty()
	# One gem better per hit, not a whole hit of artifacts
	var rng := _seeded()
	for i in 30:
		var perfect := GemData.ore_drops(PERFECT, true, true, rng)
		assert_int(perfect.count("artifact")).is_less_equal(perfect.size() / 2 + 1)

func test_hit_drop_counts_and_botched_timing_only_cracks_shards() -> void:
	var rng := _seeded()
	for i in 50:
		assert_int(GemData.ore_drops(GOOD, false, false, rng).size()).is_between(
			GemData.ORE_CHIP_MIN, GemData.ORE_CHIP_MAX)
		assert_int(GemData.ore_drops(PERFECT, false, false, rng).size()).is_between(
			GemData.ORE_CHIP_MIN + GemData.ORE_PERFECT_CHIP_BONUS,
			GemData.ORE_CHIP_MAX + GemData.ORE_PERFECT_CHIP_BONUS)
		# The break throws a bigger burst than a chip ever does
		assert_int(GemData.ore_drops(GOOD, true, false, rng).size()).is_between(
			GemData.ORE_BREAK_MIN, GemData.ORE_BREAK_MAX)
		for botched in [LATE, OVERLOAD]:
			var drops := GemData.ore_drops(botched, false, true, rng)
			assert_int(drops.count("shard")).is_equal(drops.size())

func _ore(rich := false) -> OreDeposit:
	var planet := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	add_child(planet)
	# Planets grow their own seams; these tests place their own
	for grown in planet.get_ore_deposits():
		grown.free()
	var ore := OreDeposit.new()
	ore.rich = rich
	ore.ore_index = 9
	ore.rng = _seeded()
	planet.add_child(ore)
	_gs.mark_planet_scanned(planet.save_key())
	ore.refresh()
	ore.harvest_hit.connect(func(grade, drops, final):
		_hits.append({"grade": grade, "gems": drops, "final": final}))
	return ore

## Hold the key, then let go with the sweep at `at` (a timing fraction).
func _release_at(ore: OreDeposit, at: float) -> void:
	ore.tick_harvest(0.0, true)
	ore.timing.progress = at
	ore.tick_harvest(0.0, false)

## The zone only exists once a sweep is armed, so hold first, then release inside it.
func _hit_in_zone(ore: OreDeposit) -> void:
	ore.tick_harvest(0.0, true)
	_release_at(ore, ore.timing.zone_start)

func _hit_perfect(ore: OreDeposit) -> void:
	ore.tick_harvest(0.0, true)
	_release_at(ore, ore.timing.perfect_start())

func test_a_hit_lands_when_the_key_goes_up_inside_the_zone() -> void:
	var ore := _ore()
	ore.tick_harvest(1.0, false)
	assert_object(ore.timing).is_null()
	assert_int(ore.hits_left).is_equal(OreDeposit.HITS)
	ore.tick_harvest(0.0, true)
	var first := ore.timing
	assert_bool(ore.is_harvesting()).is_true()
	ore.timing.progress = first.perfect_start()
	ore.tick_harvest(0.0, false)
	assert_int(ore.hits_left).is_equal(OreDeposit.HITS - 1)
	assert_object(ore.timing).is_not_same(first)
	assert_bool(ore.is_harvesting()).is_false()
	assert_int(_hits[0]["grade"]).is_equal(PERFECT)
	assert_array(_hits[0]["gems"]).is_not_empty()
	assert_bool(_hits[0]["final"]).is_false()

func test_early_release_keeps_progress_and_is_not_a_hit() -> void:
	var ore := _ore()
	ore.tick_harvest(0.0, true)
	ore.tick_harvest(ore.timing.duration * 0.25, true)
	ore.tick_harvest(0.0, false)
	assert_int(ore.hits_left).is_equal(OreDeposit.HITS)
	assert_float(ore.timing.progress).is_greater(0.2)
	# ...and bleeds away while the key is off
	ore.tick_harvest(0.1, false)
	assert_float(ore.timing.progress).is_less(0.25)
	assert_array(_hits).is_empty()

func test_plain_seams_break_after_three_hits_rich_after_five() -> void:
	for rich in [false, true]:
		_hits.clear()
		var ore := _ore(rich)
		var hits := OreDeposit.RICH_HITS if rich else OreDeposit.HITS
		assert_int(ore.max_hits()).is_equal(hits)
		for i in hits:
			assert_bool(ore.is_spent()).is_false()
			_hit_in_zone(ore)
		assert_bool(ore.is_spent()).is_true()
		assert_bool(_hits[-1]["final"]).is_true()
		assert_int(_hits.size()).is_equal(hits)
		# The break throws more than the chips before it
		assert_int(_hits[-1]["gems"].size()).is_greater(_hits[0]["gems"].size())

func test_rich_seams_get_the_narrow_zone() -> void:
	var plain := _ore()
	plain.tick_harvest(0.0, true)
	assert_float(plain.timing.zone_end - plain.timing.zone_start).is_equal_approx(
		HarvestTiming.NORMAL_ZONE_WIDTH, 0.0001)
	var rich := _ore(true)
	rich.tick_harvest(0.0, true)
	assert_float(rich.timing.zone_end - rich.timing.zone_start).is_equal_approx(
		HarvestTiming.TROPHY_ZONE_WIDTH, 0.0001)

func test_holding_past_the_end_overloads_into_a_botched_hit() -> void:
	var ore := _ore()
	ore.tick_harvest(0.0, true)
	ore.tick_harvest(ore.timing.duration, true)
	# An overload costs a hit like any other - it is not a free retry
	assert_int(ore.hits_left).is_equal(OreDeposit.HITS - 1)
	assert_int(_hits[-1]["grade"]).is_equal(OVERLOAD)
	assert_bool(ore.is_harvesting()).is_false()
	var drops: Array = _hits[-1]["gems"]
	assert_int(drops.count("shard")).is_equal(drops.size())

func test_lifting_off_mid_sweep_leaves_the_rest_of_the_seam_standing() -> void:
	var ore := _ore()
	_hit_in_zone(ore)
	ore.tick_harvest(0.0, true)
	ore.abort_harvest()
	assert_bool(ore.is_harvesting()).is_false()
	assert_bool(ore.is_spent()).is_false()
	assert_int(ore.hits_left).is_equal(OreDeposit.HITS - 1)
	assert_int(_hits.size()).is_equal(1)
	# Coming back finishes it off
	for i in ore.hits_left:
		_hit_in_zone(ore)
	assert_bool(ore.is_spent()).is_true()

func test_a_spent_seam_ignores_the_key() -> void:
	var ore := _ore()
	ore.spend()
	ore.tick_harvest(1.0, true)
	assert_object(ore.timing).is_null()
	assert_bool(ore.is_harvesting()).is_false()
	assert_array(_hits).is_empty()

func test_gems_knocked_loose_fly_into_the_hold() -> void:
	var planet := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	add_child(planet)
	for grown in planet.get_ore_deposits():
		grown.free()
	var ore := OreDeposit.new()
	ore.ore_index = 9
	ore.rng = _seeded()
	planet.add_child(ore)
	_gs.mark_planet_scanned(planet.save_key())
	ore.refresh()

	var ship := auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	add_child(ship)
	ship.global_position = ore.global_position + ore.normal() * PlanetLandedState.LANDED_HEIGHT
	ship.set_meta("pending_ore", ore)
	ship.state_machine.change_state("PlanetLandedState")

	_hit_perfect(ore)
	var knocked := Gem.active.size()
	assert_int(knocked).is_greater(0)
	await await_millis(2500)
	var held := 0
	for q in InventoryManager.get_all_items().values():
		held += int(q)
	assert_int(held).is_equal(knocked)
