extends GdUnitTestSuite

## Tests for ore depletion: a dig spends the seam, spent seams refuse the drill and go
## dim, they refill on play time, and their timers survive a save.

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


func _drill(ore: OreDeposit) -> OreDrill:
	var drill := auto_free(OreDrill.new()) as OreDrill
	drill.ore = ore
	add_child(drill)
	return drill


func _dig_one_layer(drill: OreDrill) -> void:
	for step in 2:
		drill.tick(0.0, true)
		drill.timing.progress = drill.timing.zone_start if step == 1 else 0.0
		drill.tick(0.0, false)


func test_spending_dims_the_seam_and_starts_its_timer() -> void:
	var ore := _ore()
	assert_bool(ore.is_spent()).is_false()
	assert_object(ore.ore_color()).is_equal(Colors.PRIMARY)
	ore.spend()
	assert_bool(ore.is_spent()).is_true()
	assert_float(ore.regrow_left()).is_equal(OreDeposit.REGROW_TIME)
	assert_object(ore.ore_color()).is_equal(Colors.PRIMARY_DIM)
	assert_object(OreMinimapTarget.new(ore).get_minimap_color()).is_equal(Colors.PRIMARY_DIM)


func test_rich_seams_take_longer_to_refill() -> void:
	var ore := _ore(true)
	ore.spend()
	assert_float(ore.regrow_left()).is_equal(OreDeposit.RICH_REGROW_TIME)
	assert_float(OreDeposit.RICH_REGROW_TIME).is_greater(OreDeposit.REGROW_TIME)


func test_every_finished_dig_spends_the_seam() -> void:
	for how in ["bank", "overload", "liftoff"]:
		var ore := _ore()
		var drill := _drill(ore)
		_dig_one_layer(drill)
		match how:
			"bank":
				drill.bank()
			"overload":
				drill.tick(0.0, true)
				drill.tick(drill.timing.duration, true)
			"liftoff":
				drill.abort()
		assert_str(drill.end_reason).is_equal(how)
		assert_bool(ore.is_spent()).is_true()


func test_a_dig_that_never_broke_ground_leaves_the_seam_full() -> void:
	var ore := _ore()
	var drill := _drill(ore)
	drill.tick(0.0, true)
	drill.tick(0.0, false)
	drill.abort()
	drill.bank()
	assert_bool(ore.is_spent()).is_false()


func test_spent_seams_refuse_the_drill() -> void:
	var ore := _ore()
	ore.spend()
	var drill := _drill(ore)
	assert_int(drill.phase).is_equal(OreDrill.Phase.DONE)
	assert_str(drill.end_reason).is_equal("spent")
	drill.tick(1.0, true)
	assert_int(drill.layer).is_equal(0)
	assert_object(drill.timing).is_null()


func test_seams_refill_after_their_time() -> void:
	var ore := _ore()
	ore.spend()
	_gs.tick_ore_regrowth(OreDeposit.REGROW_TIME - 1.0)
	assert_bool(ore.is_spent()).is_true()
	assert_float(ore.regrow_left()).is_equal_approx(1.0, 0.001)
	_gs.tick_ore_regrowth(1.0)
	assert_bool(ore.is_spent()).is_false()
	assert_dict(_gs.spent_ore).is_empty()
	assert_object(ore.ore_color()).is_equal(Colors.PRIMARY)
	assert_int(_drill(ore).phase).is_equal(OreDrill.Phase.READY)


func test_refilling_shows_the_seam_surfacing_again() -> void:
	var ore := _ore()
	ore.spend()
	ore._process(2.0)
	_gs.tick_ore_regrowth(OreDeposit.REGROW_TIME)
	ore._process(0.1)
	assert_float(ore._reveal_time).is_equal_approx(0.1, 0.001)


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
