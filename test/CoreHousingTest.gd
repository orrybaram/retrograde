extends GdUnitTestSuite

## SR-7's core (docs/OPENING.md §5): dead until the station is whole, then on standby until
## the dock's console reboots it. Its bay is four window slots and a fifth, wider one, set
## permanently out of true.


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
	assert_bool(core.reboot()).override_failure_message("a broken station's core cannot be rebooted").is_false()
	assert_bool(core.is_starting()).is_false()
	_whole(gs)
	core.refresh()
	assert_bool(core.listens()).is_true()


func test_a_reboot_starts_it_and_it_stops_listening() -> void:
	var gs := _gs()
	_whole(gs)
	var core := _core()
	assert_bool(core.reboot()).is_true()
	assert_bool(core.is_starting()).is_true()
	assert_bool(core.listens()).is_false()
	assert_bool(core.reboot()).override_failure_message("only once").is_false()


func test_the_core_is_off_the_procedure() -> void:
	var core := _core()
	assert_bool(core.is_in_group("procedure_listeners")).override_failure_message(
		"the core is rebooted from the dock's console, not by a Procedure").is_false()


func test_the_bay_is_five_slots_out_of_true() -> void:
	assert_int(CoreHousing.SLOT_X.size()).is_equal(5)
	assert_int(CoreHousing.SLOT_KINK.size()).override_failure_message(
		"every slot needs its kink: the row never straightens").is_equal(CoreHousing.SLOT_X.size())
	# the row is out of true and the cold start does not undo it
	for kink in CoreHousing.SLOT_KINK:
		assert_bool(kink.is_zero_approx()).is_false()


func test_the_slots_are_dark_until_it_catches() -> void:
	var gs := _gs()
	_whole(gs)
	var core := _core()
	assert_array(core._slot_light()).is_equal([0.0, 0.0, 0.0, 0.0, 0.0])


func test_the_bay_lights_catch_when_the_last_piece_goes_home() -> void:
	var gs := _gs()
	var core := _core()
	assert_float(core.aux_level()).override_failure_message(
		"a broken SR-7 has no light on it anywhere").is_equal(0.0)
	_whole(gs)
	core._on_section_seated(Sections.SOLAR_ARRAY_2)
	assert_float(core.aux_level()).override_failure_message(
		"they catch while the player watches, they do not snap on").is_equal(0.0)
	core._process(CoreHousing.AUX_DELAY + 0.1)
	assert_float(core.aux_level()).is_equal(1.0)


func test_a_load_snaps_the_bay_lights_on() -> void:
	var gs := _gs()
	_whole(gs)
	var core := _core()
	assert_float(core.aux_level()).override_failure_message(
		"loading into a whole station does not replay the catch").is_equal(1.0)


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
	# A save from before a new game owned its file: the cold start landed in it, the seated
	# list did not
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
