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
