extends GdUnitTestSuite

## SR-7's missing pieces ping on the minimap's sonar once they have been found - a Sweep near
## the piece, or the piece answering its empty Mount's call (Mount.call_section) - until each
## is back in it.

var _world: Node2D
var _gs: GameState
var _station: SpaceStation

func before_test() -> void:
	_world = auto_free(Node2D.new()) as Node2D
	add_child(_world)
	_gs = GameState.new()
	_world.add_child(_gs)
	_station = load("res://entities/structures/SpaceStation.tscn").instantiate() as SpaceStation
	_world.add_child(_station)
	await get_tree().process_frame

func after_test() -> void:
	Freight.clear_all(get_tree())
	NavSystem.track_home()

func _target(id: String) -> SectionMinimapTarget:
	return SectionMinimapTarget.new(Mount.for_section(get_tree(), id))

func _piece(id: String, at := Vector2(2000, 0)) -> Freight:
	return Freight.spawn_section(_world, id, at, 0.0)

func _find(id: String) -> void:
	_gs.find_section(id, "LOCATED")


func test_a_missing_piece_is_off_the_map_until_it_is_found() -> void:
	_piece(Sections.FUEL_TANK)
	var t := _target(Sections.FUEL_TANK)
	assert_bool(t.is_minimap_visible()).override_failure_message("unfound, no ping").is_false()
	Readout.on(Mount.for_section(get_tree(), Sections.FUEL_TANK)).read()
	assert_bool(t.is_minimap_visible()).override_failure_message("reading the Mount finds nothing").is_false()
	_find(Sections.FUEL_TANK)
	assert_bool(t.is_minimap_visible()).is_true()
	assert_bool(_target(Sections.SOLAR_ARRAY).mount.marks_section()) \
		.override_failure_message("finding one piece marks only that piece").is_false()


func test_a_missing_piece_pings_from_where_it_is() -> void:
	var f := _piece(Sections.FUEL_TANK)
	_find(Sections.FUEL_TANK)
	var t := _target(Sections.FUEL_TANK)
	assert_bool(t.is_minimap_visible()).is_true()
	assert_bool(t.is_ping()).override_failure_message("a missing part answers the beam").is_true()
	assert_vector(t.get_minimap_position()).is_equal(f.global_position)


func test_it_pins_to_the_rim_to_give_the_bearing() -> void:
	assert_bool(_target(Sections.SOLAR_ARRAY).pins_to_edge()).is_true()


func test_no_pulse_without_a_piece() -> void:
	assert_bool(_target(Sections.DORSAL_ARM).is_minimap_visible()).is_false()


func test_a_seated_piece_stops_pulsing() -> void:
	_piece(Sections.FUEL_TANK)
	_find(Sections.FUEL_TANK)
	var m := Mount.for_section(get_tree(), Sections.FUEL_TANK)
	var t := SectionMinimapTarget.new(m)
	m.seated = true
	assert_bool(t.is_minimap_visible()).is_false()


# --- a Mount calling its Section ---

func test_a_sweep_makes_an_empty_mount_call_and_its_section_answer() -> void:
	var f := _piece(Sections.SOLAR_ARRAY, Vector2(1100, 0))
	_gs.progress.mark(Progress.SEATED_SECTIONS, Sections.FUEL_TANK)  # so the log speaks of it
	var m := Mount.for_section(get_tree(), Sections.SOLAR_ARRAY)
	m.on_swept()
	assert_bool(m.is_calling()).is_true()
	assert_int(m.get_children().filter(func(c): return c is SonarEcho).size()) \
		.override_failure_message("the Mount's own ring goes out").is_equal(1)
	var gap := m.global_position.distance_to(f.global_position)
	await await_millis(int(gap / Mount.CALL_SPEED * 1000.0) + 150)
	assert_int(f.get_children().filter(func(c): return c is SonarEcho).size()) \
		.override_failure_message("the Section answers with a ring of its own").is_equal(1)
	assert_bool(_gs.progress.holds(Progress.FOUND_SECTIONS, Sections.SOLAR_ARRAY)) \
		.override_failure_message("not found until the answer gets back").is_false()
	await await_millis(int(gap / Mount.CALL_SPEED * 1000.0) + 150)
	assert_bool(_gs.progress.holds(Progress.FOUND_SECTIONS, Sections.SOLAR_ARRAY)).is_true()
	assert_bool(_target(Sections.SOLAR_ARRAY).is_minimap_visible()).is_true()
	var last: Dictionary = _gs.ship_log.entries[-1]
	assert_str(last["source"]).is_equal(ShipLog.SONAR)
	assert_str(last["name"]).is_equal("SOLAR ARRAY")
	assert_str(last["value"]).is_equal("LOCATED")
	assert_bool(m.is_calling()).is_false()


func test_a_mount_does_not_call_for_a_found_or_missing_section() -> void:
	var m := Mount.for_section(get_tree(), Sections.DORSAL_ARM)
	assert_bool(m.call_section()).override_failure_message("no piece out there").is_false()
	_piece(Sections.DORSAL_ARM)
	_gs.find_section(Sections.DORSAL_ARM, "CONTACT")
	assert_bool(m.call_section()).override_failure_message("already found").is_false()


# --- the station's broken parts, in red on its outline ---

func test_the_station_marks_each_empty_mount_and_the_hanging_wing() -> void:
	var t := SpaceStationMinimapTarget.new(_station)
	var mounts := get_tree().get_nodes_in_group("mounts")
	assert_int(t.broken_points().size()) \
		.override_failure_message("every Mount empty, and the wing off true") \
		.is_equal(mounts.size() + 1)
	assert_bool(t.broken_points().has(Mount.for_section(get_tree(), Sections.FUEL_TANK).global_position)).is_true()
	for m in mounts:
		m.seated = true
	assert_int(t.broken_points().size()).override_failure_message("only the wing").is_equal(1)
	for n in get_tree().get_nodes_in_group("nudges"):
		n.seated = true
	assert_bool(t.broken_points().is_empty()).override_failure_message("whole, nothing red").is_true()
