extends GdUnitTestSuite

## SR-7's core (docs/OPENING.md §5): dead until the station is whole, then listening for
## its placard's Procedure, and saying how wrong a wrong one is.


func _gs() -> GameState:
	var gs: GameState = auto_free(GameState.new())
	add_child(gs)
	return gs


func _whole(gs: GameState) -> void:
	for id in Sections.DATA.keys() + [Sections.SOLAR_ARRAY_2]:
		gs.mark_section_seated(id)


func _core() -> CoreHousing:
	var core: CoreHousing = auto_free(CoreHousing.new())
	add_child(core)
	core.refresh()
	return core


func test_whole_needs_all_four_pieces() -> void:
	var gs := _gs()
	assert_bool(CoreHousing.is_whole(gs)).is_false()
	for id in Sections.DATA.keys():
		gs.mark_section_seated(id)
	assert_bool(CoreHousing.is_whole(gs)).override_failure_message("the hanging wing counts too").is_false()
	gs.mark_section_seated(Sections.SOLAR_ARRAY_2)
	assert_bool(CoreHousing.is_whole(gs)).is_true()
	assert_bool(CoreHousing.is_whole(null)).is_false()


func test_dead_until_whole() -> void:
	var gs := _gs()
	var core := _core()
	assert_bool(core.listens()).is_false()
	core.on_procedure([1, 1, 1, 1])
	assert_int(core.segments_lit()).is_equal(0)
	_whole(gs)
	core.refresh()
	assert_bool(core.listens()).is_true()


func test_a_wrong_procedure_lights_a_count_of_segments() -> void:
	var gs := _gs()
	_whole(gs)
	var core := _core()
	core.on_procedure([1, 1, 1, 1])
	assert_int(core.segments_lit()).is_equal(3)
	assert_bool(core.is_starting()).is_false()
	core._process(CoreHousing.SEGMENT_HOLD + 0.1)
	assert_int(core.segments_lit()).is_equal(0)


func test_the_right_procedure_starts_it_and_it_stops_listening() -> void:
	var gs := _gs()
	_whole(gs)
	var core := _core()
	core.on_procedure([1, 1, 2, 1])
	assert_bool(core.is_starting()).is_true()
	assert_bool(core.listens()).is_false()


func test_a_started_core_is_deaf() -> void:
	var gs := _gs()
	_whole(gs)
	gs.core_started = true
	var core := _core()
	assert_bool(core.started).is_true()
	assert_bool(core.listens()).is_false()


# --- what a save brings back ---

func test_a_restored_station_comes_back_whole_and_running() -> void:
	var gs := _gs()
	gs.restore_station(PackedStringArray(GameState.station_pieces()), true)
	assert_bool(gs.station_whole()).is_true()
	assert_bool(gs.core_started).is_true()


func test_a_running_core_brings_its_pieces_back_with_it() -> void:
	var gs := _gs()
	# A save that kept the cold start and lost the seated list, the way the dev panel's
	# core toggle used to leave one
	gs.restore_station(PackedStringArray([Sections.SOLAR_ARRAY_2]), true)
	assert_bool(gs.station_whole()).override_failure_message(
		"a lit station is never in pieces - the core does not listen until it is whole").is_true()


func test_a_cold_core_leaves_the_pieces_where_the_save_had_them() -> void:
	var gs := _gs()
	gs.restore_station(PackedStringArray([Sections.SOLAR_ARRAY_2]), false)
	assert_bool(gs.is_section_seated(Sections.SOLAR_ARRAY_2)).is_true()
	assert_bool(gs.is_section_seated(Sections.FUEL_TANK)).is_false()
	assert_bool(gs.core_started).is_false()


func test_a_load_clears_what_the_game_before_it_seated() -> void:
	var gs := _gs()
	_whole(gs)
	gs.restore_station(PackedStringArray(), false)
	assert_bool(gs.is_section_seated(Sections.FUEL_TANK)).is_false()
	assert_bool(gs.station_whole()).is_false()
