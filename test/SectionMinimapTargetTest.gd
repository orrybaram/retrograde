extends GdUnitTestSuite

## SR-7's missing pieces ping on the minimap's sonar once the ship has
## read their Mount up close, until each is back in it.

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

func _read_mount(id: String) -> void:
	Readout.on(Mount.for_section(get_tree(), id)).read()


func test_a_missing_piece_is_off_the_map_until_its_mount_is_read() -> void:
	_piece(Sections.FUEL_TANK)
	var t := _target(Sections.FUEL_TANK)
	assert_bool(t.is_minimap_visible()).override_failure_message("unread Mount, no ping").is_false()
	_read_mount(Sections.FUEL_TANK)
	assert_bool(t.is_minimap_visible()).is_true()
	assert_bool(_target(Sections.SOLAR_ARRAY).mount.marks_section()) \
		.override_failure_message("reading one Mount marks only its own piece").is_false()


func test_a_missing_piece_pings_from_where_it_is() -> void:
	var f := _piece(Sections.FUEL_TANK)
	_read_mount(Sections.FUEL_TANK)
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
	_read_mount(Sections.FUEL_TANK)
	var m := Mount.for_section(get_tree(), Sections.FUEL_TANK)
	var t := SectionMinimapTarget.new(m)
	m.seated = true
	assert_bool(t.is_minimap_visible()).is_false()
