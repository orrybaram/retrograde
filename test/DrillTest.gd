extends GdUnitTestSuite

## Tests for drilling an ore seam: depth / PERFECT gem tiers, the layer sequence,
## early release, banking, overload kickback, and gems reaching the hold.

const GOOD := HarvestTiming.Grade.GOOD
const PERFECT := HarvestTiming.Grade.PERFECT
const LATE := HarvestTiming.Grade.LATE

var _gs: GameState
var _events: Array = []


func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	add_child(_gs)
	_events.clear()
	EventBus.drill_struck.connect(_on_struck)
	EventBus.dig_ended.connect(_on_ended)
	InventoryManager.clear_inventory()


func after_test() -> void:
	EventBus.drill_struck.disconnect(_on_struck)
	EventBus.dig_ended.disconnect(_on_ended)
	InventoryManager.clear_inventory()
	Gem.clear_all()


func _on_struck(_ore, grade, gems, layer, final) -> void:
	_events.append({"type": "struck", "grade": grade, "gems": gems, "layer": layer, "final": final})


func _on_ended(_ore, reason, layers) -> void:
	_events.append({"type": "ended", "reason": reason, "layers": layers})


func _seeded(seed_value := 7) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _mean_tier(depth: int) -> float:
	var rng := _seeded(depth)
	var total := 0
	for i in 2000:
		total += GemData.drill_roll(depth, rng)
	return total / 2000.0


## Credits from one full dig of `layers` layers starting at `start_depth`, all GOOD.
func _dig_value(start_depth: int, layers: int, rng: RandomNumberGenerator) -> int:
	var ids: Array[String] = []
	for i in layers:
		ids.append_array(GemData.drill_drops(start_depth + i, GOOD, rng))
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


func test_a_dig_pays_far_better_than_a_scrap_node() -> void:
	var rng := _seeded(3)
	var dig := 0
	var scrap := 0
	for i in 200:
		dig += _dig_value(0, OreDrill.LAYERS, rng)
		scrap += _scrap_value(rng)
	# A plain 3-layer seam is worth several scrap nodes, and a rich moon seam far more
	assert_float(float(dig) / float(scrap)).is_greater(2.0)
	var rich := 0
	for i in 200:
		rich += _dig_value(1, OreDrill.RICH_LAYERS, rng)
	assert_float(float(rich) / float(dig)).is_greater(2.0)


func test_deeper_layers_roll_better_gems() -> void:
	for depth in GemData.DRILL_DEPTH_WEIGHTS.size() - 1:
		assert_float(_mean_tier(depth + 1)).is_greater(_mean_tier(depth))


func test_perfect_bumps_the_best_gem_in_the_layer() -> void:
	assert_array(GemData.bump_best(["shard", "gem", "shard"])).is_equal(["shard", "crystal", "shard"])
	assert_array(GemData.bump_best(["crystal", "artifact"])).is_equal(["crystal", "artifact"])
	assert_array(GemData.bump_best([])).is_empty()
	# One gem better per layer, not a whole layer of artifacts
	var rng := _seeded()
	for i in 30:
		var perfect := GemData.drill_drops(4, PERFECT, rng)
		assert_int(perfect.count("artifact")).is_less_equal(perfect.size() / 2 + 1)


func test_layer_drop_counts_and_late_cracks() -> void:
	var rng := _seeded()
	for i in 50:
		assert_int(GemData.drill_drops(1, GOOD, rng).size()).is_between(GemData.DRILL_MIN, GemData.DRILL_MAX)
		assert_int(GemData.drill_drops(1, PERFECT, rng).size()).is_between(
			GemData.DRILL_MIN + GemData.PERFECT_DRILL_BONUS, GemData.DRILL_MAX + GemData.PERFECT_DRILL_BONUS)
		var late := GemData.drill_drops(4, LATE, rng)
		assert_int(late.count("shard")).is_equal(late.size())


func _ore(rich := false) -> OreDeposit:
	var planet := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	add_child(planet)
	# Planets grow their own seams; these tests place their own
	for grown in planet.get_ore_deposits():
		grown.free()
	var ore := OreDeposit.new()
	ore.rich = rich
	ore.ore_index = 9
	planet.add_child(ore)
	return ore


func _drill(ore: OreDeposit, ship: Ship = null) -> OreDrill:
	var drill: OreDrill
	if ship:
		drill = OreDrill.attach(ship, ore)
	else:
		drill = auto_free(OreDrill.new()) as OreDrill
		drill.ore = ore
		add_child(drill)
	drill.rng = _seeded()
	return drill


## Hold the key, then let go with the sweep at `at` (a timing fraction).
func _release_at(drill: OreDrill, at: float) -> void:
	drill.tick(0.0, true)
	drill.timing.progress = at
	drill.tick(0.0, false)


func test_a_dig_starts_on_hold_and_breaks_layers_in_the_zone() -> void:
	var drill := _drill(_ore())
	drill.tick(1.0, false)
	assert_int(drill.phase).is_equal(OreDrill.Phase.READY)
	_release_at(drill, 0.0)
	assert_int(drill.phase).is_equal(OreDrill.Phase.DIGGING)
	var first := drill.timing
	_release_at(drill, first.perfect_start())
	assert_int(drill.layer).is_equal(1)
	assert_object(drill.timing).is_not_same(first)
	assert_array(drill.dug).is_not_empty()
	assert_int(_events[0]["grade"]).is_equal(PERFECT)
	assert_array(_events[0]["gems"]).is_equal(drill.dug)


func test_early_release_keeps_progress_and_is_not_a_layer() -> void:
	var drill := _drill(_ore())
	drill.tick(0.0, true)
	drill.tick(drill.timing.duration * 0.25, true)
	drill.tick(0.0, false)
	assert_int(drill.layer).is_equal(0)
	assert_float(drill.timing.progress).is_greater(0.2)
	drill.tick(0.1, false)
	assert_float(drill.timing.progress).is_less(0.25)
	assert_array(_events).is_empty()


func test_normal_sites_bottom_out_after_three_layers_rich_after_four() -> void:
	for rich in [false, true]:
		_events.clear()
		var drill := _drill(_ore(rich))
		_release_at(drill, 0.0)  # starts the dig
		for i in (OreDrill.RICH_LAYERS if rich else OreDrill.LAYERS):
			assert_int(drill.phase).is_equal(OreDrill.Phase.DIGGING)
			_release_at(drill, drill.timing.zone_start)
		assert_int(drill.phase).is_equal(OreDrill.Phase.DONE)
		assert_str(drill.end_reason).is_equal("bottom")
		assert_bool(_events[-2]["final"]).is_true()
		assert_dict(_events[-1]).is_equal({"type": "ended", "reason": "bottom", "layers": drill.layer_count()})


func test_deep_layers_get_the_narrow_zone() -> void:
	var drill := _drill(_ore(true))
	_release_at(drill, 0.0)
	var width := drill.timing.zone_end - drill.timing.zone_start
	assert_float(width).is_equal_approx(HarvestTiming.NORMAL_ZONE_WIDTH, 0.0001)
	_release_at(drill, drill.timing.zone_start)
	_release_at(drill, drill.timing.zone_start)
	assert_int(drill.depth()).is_equal(OreDrill.TROPHY_DEPTH)
	width = drill.timing.zone_end - drill.timing.zone_start
	assert_float(width).is_equal_approx(HarvestTiming.TROPHY_ZONE_WIDTH, 0.0001)


func test_bank_between_layers_keeps_the_haul() -> void:
	var drill := _drill(_ore())
	_release_at(drill, 0.0)
	assert_bool(drill.can_bank()).is_false()
	drill.bank()
	assert_int(drill.phase).is_equal(OreDrill.Phase.READY)
	_release_at(drill, 0.0)
	_release_at(drill, drill.timing.zone_start)
	drill.tick(0.0, true)
	assert_bool(drill.can_bank()).is_false()
	drill.tick(0.0, false)
	var dug := drill.dug.duplicate()
	assert_bool(drill.can_bank()).is_true()
	drill.bank()
	assert_int(drill.phase).is_equal(OreDrill.Phase.DONE)
	assert_str(drill.end_reason).is_equal("bank")
	assert_array(drill.dug).is_equal(dug)
	drill.tick(1.0, true)
	assert_int(drill.layer).is_equal(1)


func _ship() -> Ship:
	var ship := auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	add_child(ship)
	return ship


func test_overload_ends_the_dig_with_kickback() -> void:
	var ship := _ship()
	var drill := _drill(_ore(), ship)
	_release_at(drill, 0.0)
	_release_at(drill, drill.timing.zone_start)
	var dug := drill.dug.duplicate()
	var hull := ship.hull_strength
	drill.tick(0.0, true)
	drill.tick(drill.timing.duration, true)
	assert_int(drill.phase).is_equal(OreDrill.Phase.DONE)
	assert_str(drill.end_reason).is_equal("overload")
	assert_float(ship.hull_strength).is_equal(hull - OreDrill.KICKBACK_DAMAGE)
	assert_array(drill.dug).is_equal(dug)
	assert_dict(_events[-1]).is_equal({"type": "ended", "reason": "overload", "layers": 1})


func test_liftoff_mid_dig_ends_it() -> void:
	var drill := _drill(_ore())
	_release_at(drill, 0.0)
	drill.abort()
	assert_int(drill.phase).is_equal(OreDrill.Phase.READY)
	_release_at(drill, 0.0)
	_release_at(drill, drill.timing.zone_start)
	drill.abort()
	assert_str(drill.end_reason).is_equal("liftoff")


func test_dug_gems_fly_into_the_hold() -> void:
	var ship := _ship()
	var ore := _ore()
	ship.global_position = ore.global_position + Vector2(PlanetLandedState.LANDED_HEIGHT, 0)
	var drill := _drill(ore, ship)
	_release_at(drill, 0.0)
	_release_at(drill, drill.timing.perfect_start())
	var dug := drill.dug.size()
	assert_int(Gem.active.size()).is_equal(dug)
	await await_millis(2500)
	var held := 0
	for q in InventoryManager.get_all_items().values():
		held += int(q)
	assert_int(held).is_equal(dug)
