extends GdUnitTestSuite

## Tests for landing site depletion: digs spend a site, spent sites refuse the drill and
## dim their beacon, they regrow on play time, and the timers survive a save.

const SAVE_FILE := "user://sites_test_save.cfg"

var _gs: GameState


func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	add_child(_gs)
	_gs.set_process(false)  # tests drive the regrow clock themselves


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))


func _site(rich := false) -> LandingSite:
	var planet := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	add_child(planet)
	var site := LandingSite.new()
	site.rich = rich
	planet.add_child(site)
	_gs.mark_planet_scanned(planet.save_key())
	site.refresh()
	return site


func _drill(site: LandingSite) -> SiteDrill:
	var drill := auto_free(SiteDrill.new()) as SiteDrill
	drill.site = site
	add_child(drill)
	return drill


func _dig_one_layer(drill: SiteDrill) -> void:
	for step in 2:
		drill.tick(0.0, true)
		drill.timing.progress = drill.timing.zone_start if step == 1 else 0.0
		drill.tick(0.0, false)


func test_spending_dims_the_site_and_starts_its_timer() -> void:
	var site := _site()
	assert_bool(site.is_spent()).is_false()
	assert_object(site.beacon_color()).is_equal(Colors.PRIMARY)
	site.spend()
	assert_bool(site.is_spent()).is_true()
	assert_float(site.regrow_left()).is_equal(LandingSite.REGROW_TIME)
	assert_object(site.beacon_color()).is_equal(Colors.PRIMARY_DIM)
	assert_object(LandingSiteMinimapTarget.new(site).get_minimap_color()).is_equal(Colors.PRIMARY_DIM)


func test_rich_sites_take_longer_to_regrow() -> void:
	var site := _site(true)
	site.spend()
	assert_float(site.regrow_left()).is_equal(LandingSite.RICH_REGROW_TIME)
	assert_float(LandingSite.RICH_REGROW_TIME).is_greater(LandingSite.REGROW_TIME)


func test_every_finished_dig_spends_the_site() -> void:
	for how in ["bank", "overload", "liftoff"]:
		var site := _site()
		var drill := _drill(site)
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
		assert_bool(site.is_spent()).is_true()


func test_a_dig_that_never_broke_ground_leaves_the_site_fresh() -> void:
	var site := _site()
	var drill := _drill(site)
	drill.tick(0.0, true)
	drill.tick(0.0, false)
	drill.abort()
	drill.bank()
	assert_bool(site.is_spent()).is_false()


func test_spent_sites_refuse_the_drill() -> void:
	var site := _site()
	site.spend()
	var drill := _drill(site)
	assert_int(drill.phase).is_equal(SiteDrill.Phase.DONE)
	assert_str(drill.end_reason).is_equal("spent")
	drill.tick(1.0, true)
	assert_int(drill.layer).is_equal(0)
	assert_object(drill.timing).is_null()


func test_sites_regrow_after_their_time() -> void:
	var site := _site()
	site.spend()
	_gs.tick_site_regrowth(LandingSite.REGROW_TIME - 1.0)
	assert_bool(site.is_spent()).is_true()
	assert_float(site.regrow_left()).is_equal_approx(1.0, 0.001)
	_gs.tick_site_regrowth(1.0)
	assert_bool(site.is_spent()).is_false()
	assert_dict(_gs.spent_sites).is_empty()
	assert_object(site.beacon_color()).is_equal(Colors.PRIMARY)
	assert_int(_drill(site).phase).is_equal(SiteDrill.Phase.READY)


func test_regrowth_pings_the_beacon() -> void:
	var site := _site()
	site.spend()
	site._process(2.0)
	_gs.tick_site_regrowth(LandingSite.REGROW_TIME)
	site._process(0.1)
	assert_float(site._reveal_time).is_equal_approx(0.1, 0.001)


func test_new_game_regrows_everything() -> void:
	var site := _site()
	site.spend()
	_gs.reset_all_state()
	assert_dict(_gs.spent_sites).is_empty()


func test_regrow_timers_round_trip_through_the_save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "credits", 5)
	cfg.save(SAVE_FILE)
	Save.save_site_regrowth({"Veld/Rook#SiteA": 123.5, "Sun/Crom#SiteB": 7.0}, SAVE_FILE)
	var loaded := Save.load_site_regrowth(SAVE_FILE)
	assert_dict(loaded).is_equal({"Veld/Rook#SiteA": 123.5, "Sun/Crom#SiteB": 7.0})
	cfg.load(SAVE_FILE)
	assert_int(cfg.get_value("stats", "credits")).is_equal(5)


func test_regrow_save_needs_an_existing_save() -> void:
	Save.save_site_regrowth({"Crom#SiteA": 1.0}, SAVE_FILE)
	assert_bool(FileAccess.file_exists(SAVE_FILE)).is_false()
	assert_dict(Save.load_site_regrowth(SAVE_FILE)).is_empty()
