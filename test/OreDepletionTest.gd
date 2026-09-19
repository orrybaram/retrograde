extends GdUnitTestSuite

## Tests for ore depletion: harvesting crumbles the rock away, the last hit spends the
## seam, a spent seam leaves the view and the map, seams refill on play time, and their
## timers survive a save.

const SAVE_FILE := "user://ore_test_save.cfg"

var _gs: GameState


func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	add_child(_gs)
	_gs.set_process(false)  # tests drive the regrow clock themselves


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))


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
	_gs.mark_planet_scanned(planet.save_key())
	ore.refresh()
	return ore


## Hold the key, then let go inside the zone: one landed hit.
func _one_hit(ore: OreDeposit) -> void:
	ore.tick_harvest(0.0, true)
	ore.timing.progress = ore.timing.zone_start
	ore.tick_harvest(0.0, false)


func test_spending_breaks_the_seam_up_and_starts_its_timer() -> void:
	var ore := _ore()
	var marker := OreMinimapTarget.new(ore)
	assert_bool(ore.is_spent()).is_false()
	assert_float(ore.remaining()).is_equal(1.0)
	assert_bool(marker.is_minimap_visible()).is_true()

	ore.spend()
	assert_bool(ore.is_spent()).is_true()
	assert_float(ore.regrow_left()).is_equal(OreDeposit.REGROW_TIME)
	assert_bool(marker.is_minimap_visible()).is_false()
	# The last rock crumbles over CRUMBLE_TIME...
	assert_bool(ore.visible).is_true()
	ore._process(OreDeposit.CRUMBLE_TIME)
	assert_float(ore.remaining()).is_equal(0.0)
	# ...and the seam stays on screen while its debris is still in the air
	assert_bool(ore.visible).is_true()
	ore._process(OreDeposit.SHARD_LIFE.y)
	assert_int(ore.debris_count()).is_equal(0)
	assert_bool(ore.visible).is_false()


func test_breaking_a_chunk_throws_rock() -> void:
	var ore := _ore()
	assert_int(ore.debris_count()).is_equal(0)
	ore.set_dug(0.5)
	ore._process(0.05)
	assert_int(ore.debris_count()).is_greater(0)
	# The splinters settle rather than hanging around
	ore._process(OreDeposit.SHARD_LIFE.y + 0.1)
	assert_int(ore.debris_count()).is_equal(0)


func test_harvesting_crumbles_the_rock_away_as_it_goes() -> void:
	var ore := _ore()
	var share := 1.0 / float(ore.max_hits())
	_one_hit(ore)
	assert_float(ore.harvest_share()).is_equal_approx(share, 0.001)
	ore._process(OreDeposit.CRUMBLE_TIME)
	assert_float(ore.remaining()).is_equal_approx(1.0 - share, 0.001)
	assert_bool(ore.visible).is_true()
	# A seam only ever erodes: an early release that loses progress doesn't put rock back
	ore.set_dug(0.0)
	assert_float(ore.remaining()).is_equal_approx(1.0 - share, 0.001)


func test_a_seam_spent_before_it_surfaces_is_never_shown() -> void:
	var ore := _ore()
	ore.spend()
	ore.refresh()  # as a restored save does
	assert_float(ore.remaining()).is_equal(0.0)
	assert_bool(ore.visible).is_false()
	assert_bool(ore.tracking_target().is_valid()).is_false()


func test_rich_seams_take_longer_to_refill() -> void:
	var ore := _ore(true)
	ore.spend()
	assert_float(ore.regrow_left()).is_equal(OreDeposit.RICH_REGROW_TIME)
	assert_float(OreDeposit.RICH_REGROW_TIME).is_greater(OreDeposit.REGROW_TIME)


func test_only_the_last_hit_spends_the_seam() -> void:
	var ore := _ore()
	for i in ore.max_hits() - 1:
		_one_hit(ore)
		# Leaving now keeps the haul and leaves the rest of the rock standing
		ore.abort_harvest()
		assert_bool(ore.is_spent()).is_false()
	_one_hit(ore)
	assert_bool(ore.is_spent()).is_true()


func test_a_sweep_that_never_landed_leaves_the_seam_full() -> void:
	var ore := _ore()
	ore.tick_harvest(0.0, true)
	ore.tick_harvest(0.0, false)
	ore.abort_harvest()
	assert_bool(ore.is_spent()).is_false()
	assert_int(ore.hits_left).is_equal(ore.max_hits())


func test_spent_seams_refuse_the_key() -> void:
	var ore := _ore()
	ore.spend()
	ore.tick_harvest(1.0, true)
	assert_bool(ore.is_harvesting()).is_false()
	assert_object(ore.timing).is_null()


func test_seams_refill_after_their_time() -> void:
	var ore := _ore()
	ore.spend()
	_gs.tick_ore_regrowth(OreDeposit.REGROW_TIME - 1.0)
	assert_bool(ore.is_spent()).is_true()
	assert_float(ore.regrow_left()).is_equal_approx(1.0, 0.001)
	_gs.tick_ore_regrowth(1.0)
	assert_bool(ore.is_spent()).is_false()
	assert_dict(_gs.spent_ore).is_empty()
	# Refilled rock is a full set of hits again
	ore._process(0.1)
	assert_int(ore.hits_left).is_equal(ore.max_hits())
	ore.tick_harvest(0.0, true)
	assert_bool(ore.is_harvesting()).is_true()


func test_refilling_shows_fresh_rock_surfacing_again() -> void:
	var ore := _ore()
	ore.spend()
	ore._process(2.0)
	assert_bool(ore.visible).is_false()
	_gs.tick_ore_regrowth(OreDeposit.REGROW_TIME)
	ore._process(0.1)
	assert_float(ore._reveal_time).is_equal_approx(0.1, 0.001)
	assert_float(ore.remaining()).is_equal(1.0)
	assert_bool(ore.visible).is_true()


func test_new_game_refills_everything() -> void:
	var ore := _ore()
	ore.spend()
	_gs.reset_all_state()
	assert_dict(_gs.spent_ore).is_empty()


func test_regrow_timers_round_trip_through_the_save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "credits", 5)
	cfg.save(SAVE_FILE)
	Save.save_ore_regrowth({"Veld/Rook#0": 123.5, "Sun/Crom#1": 7.0}, SAVE_FILE)
	var loaded := Save.load_ore_regrowth(SAVE_FILE)
	assert_dict(loaded).is_equal({"Veld/Rook#0": 123.5, "Sun/Crom#1": 7.0})
	cfg.load(SAVE_FILE)
	assert_int(cfg.get_value("stats", "credits")).is_equal(5)


func test_regrow_save_needs_an_existing_save() -> void:
	Save.save_ore_regrowth({"Crom#0": 1.0}, SAVE_FILE)
	assert_bool(FileAccess.file_exists(SAVE_FILE)).is_false()
	assert_dict(Save.load_ore_regrowth(SAVE_FILE)).is_empty()
