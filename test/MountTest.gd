extends GdUnitTestSuite

## Seating a Section (docs/adr/0012, docs/OPENING.md §2-4): SR-7's FUEL TANK, SOLAR ARRAY
## and DORSAL ARM each go back into their own Mount, cut where they were taken off, and
## only there.

const SAVE_FILE := "user://mount_test_save.cfg"
const ALL := [Sections.FUEL_TANK, Sections.SOLAR_ARRAY, Sections.DORSAL_ARM]
const PARTS := {
	Sections.FUEL_TANK: "Visuals/FuelTank",
	Sections.SOLAR_ARRAY: "Visuals/SolarArray",
	Sections.DORSAL_ARM: "Visuals/DorsalArm",
}

var _world: Node2D
var _station: SpaceStation

func before_test() -> void:
	_world = auto_free(Node2D.new()) as Node2D
	add_child(_world)
	_station = load("res://entities/structures/SpaceStation.tscn").instantiate() as SpaceStation
	_world.add_child(_station)
	await get_tree().process_frame

func after_test() -> void:
	Freight.clear_all(get_tree())
	NavSystem.track_home()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))

func _mount(id: String) -> Mount:
	return Mount.for_section(get_tree(), id)

func _part(id: String) -> Polygon2D:
	return _station.get_node(PARTS[id]) as Polygon2D

func _piece(id: String, xf: Transform2D) -> Freight:
	return Freight.spawn_section(_world, id, xf.origin, xf.get_rotation())

func _sections(id: String) -> Array:
	return get_tree().get_nodes_in_group("freight").filter(
		func(n): return not n.is_queued_for_deletion() and n.section == id)

func _solid_at(station_point: Vector2) -> bool:
	for child in _station.get_children():
		var c := child as CollisionPolygon2D
		if c and not c.disabled and c.is_inside_tree() \
				and Geometry2D.is_point_in_polygon(c.transform.affine_inverse() * station_point, c.polygon):
			return true
	return false

## Section `id`'s gap, as a box in its Mount's frame.
func _gap_in_mount(id: String) -> Rect2:
	var m := _mount(id)
	var to_mount := m.global_transform.affine_inverse() * _part(id).global_transform
	return Freight.bounds(to_mount * m._gaps[0])

# --- the cut ---

func test_a_new_station_is_missing_all_three_sections() -> void:
	for id in ALL:
		assert_bool(_part(id).visible).is_false()
		assert_bool(_mount(id).seated).is_false()

func test_there_is_one_mount_per_section_and_no_mast() -> void:
	assert_int(get_tree().get_nodes_in_group("mounts").size()).is_equal(3)
	assert_object(_station.get_node_or_null("Mast1Mount")).is_null()

func test_each_mount_sits_in_the_middle_of_its_gap() -> void:
	for id in ALL:
		var gaps := _mount(id)._gaps
		assert_int(gaps.size()).is_equal(1)
		assert_vector(_gap_in_mount(id).get_center()).is_equal_approx(Vector2.ZERO, Vector2(1, 1))

func test_each_section_is_a_little_smaller_than_its_gap_along_its_own_axis() -> void:
	for id in ALL:
		var gap := _gap_in_mount(id)
		var piece := Freight.bounds(PackedVector2Array(Sections.DATA[id]["outline"]))
		assert_float(piece.size.x).is_less(gap.size.x)
		assert_float(piece.size.y).is_less(gap.size.y)
		assert_float(gap.size.x - piece.size.x).is_less(12.0)

func test_each_lug_faces_open_space_once_seated() -> void:
	for id in ALL:
		var m := _mount(id)
		var facing: Vector2 = m.transform.basis_xform(Sections.DATA[id]["lug_facing"])
		assert_float(facing.dot(m.position)).is_greater(0.0)

func test_the_tank_was_cut_from_its_strut_and_both_cradle_bars() -> void:
	var m := _mount(Sections.FUEL_TANK)
	var edges := Mount.cut_edges(Freight.bounds(m._gaps[0]), m._covers())
	assert_array(edges.map(func(e): return e[2])).contains_exactly_in_any_order([Vector2.RIGHT, Vector2.DOWN, Vector2.UP])

func test_the_array_was_cut_at_the_keel_and_the_arm_at_its_plate() -> void:
	var array := _mount(Sections.SOLAR_ARRAY)
	assert_array(Mount.cut_edges(Freight.bounds(array._gaps[0]), array._covers()).map(func(e): return e[2])) \
		.contains_exactly([Vector2.LEFT])
	var arm := _mount(Sections.DORSAL_ARM)
	assert_array(Mount.cut_edges(Freight.bounds(arm._gaps[0]), arm._covers()).map(func(e): return e[2])) \
		.contains_exactly([Vector2.UP])

func test_bolt_holes_run_evenly_along_a_cut_and_clear_of_its_ends() -> void:
	var at := Mount.bolt_stations(50.0)
	assert_int(at.size()).is_equal(5)
	assert_float(at[0]).is_equal_approx(5.0, 0.01)
	assert_float(at[1] - at[0]).is_equal_approx(Mount.BOLT_PITCH, 0.01)
	assert_float(at[4]).is_equal_approx(45.0, 0.01)
	assert_int(Mount.bolt_stations(6.0).size()).is_equal(0)

func test_the_gaps_are_not_walls_while_the_mounts_are_empty() -> void:
	await get_tree().process_frame
	for id in ALL:
		assert_bool(_solid_at(_mount(id).position)).is_false()
	assert_bool(_solid_at(Vector2(0, 15))).is_true()    # the core is still there
	assert_bool(_solid_at(Vector2(0, -375))).is_true()  # and the ring pods

func test_cutting_a_hole_through_a_waist_splits_the_polygon() -> void:
	var bar := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 10), Vector2(0, 10)])
	var hole := PackedVector2Array([Vector2(40, -5), Vector2(60, -5), Vector2(60, 15), Vector2(40, 15)])
	assert_int(Mount.cut_polygon(bar, [hole]).size()).is_equal(2)

# --- fitting ---

func test_a_section_fits_within_40px_and_30_degrees() -> void:
	var m := _mount(Sections.FUEL_TANK).global_transform
	assert_bool(Mount.in_tolerance(m * Transform2D(0.0, Vector2(39, 0)), m)).is_true()
	assert_bool(Mount.in_tolerance(m * Transform2D(deg_to_rad(29), Vector2.ZERO), m)).is_true()
	assert_bool(Mount.in_tolerance(m * Transform2D(0.0, Vector2(0, 41)), m)).is_false()
	assert_bool(Mount.in_tolerance(m * Transform2D(deg_to_rad(31), Vector2.ZERO), m)).is_false()

func test_each_section_fits_only_its_own_mount() -> void:
	for id in ALL:
		var at := _mount(id).global_transform
		var plain := Freight.spawn(_world, at.origin, at.get_rotation())
		assert_object(Mount.accepting(get_tree(), plain)).is_null()
		assert_object(Mount.accepting(get_tree(), _piece(id, at))).is_same(_mount(id))
	var tank_at_arm := _piece(Sections.FUEL_TANK, _mount(Sections.DORSAL_ARM).global_transform)
	assert_object(Mount.accepting(get_tree(), tank_at_arm)).is_null()

func test_a_section_fits_turned_end_for_end() -> void:
	var m := _mount(Sections.SOLAR_ARRAY)
	var flipped := _piece(Sections.SOLAR_ARRAY, m.global_transform * Transform2D(PI + 0.2, Vector2(20, -5)))
	assert_object(Mount.accepting(get_tree(), flipped)).is_same(m)

func test_a_section_out_of_tolerance_does_not_fit() -> void:
	var m := _mount(Sections.DORSAL_ARM)
	var arm := _piece(Sections.DORSAL_ARM, m.global_transform * Transform2D(0.0, Vector2(-60, 0)))
	assert_object(Mount.accepting(get_tree(), arm)).is_null()

func test_clamping_a_section_tracks_its_mount() -> void:
	var tank := _piece(Sections.FUEL_TANK, Transform2D(0.0, Vector2(3000, 0)))
	assert_object((tank.destination() as NodeTrackingTarget).node).is_same(_mount(Sections.FUEL_TANK))
	assert_str(tank.destination().get_label()).is_equal("MOUNT")
	var plain := Freight.spawn(_world, Vector2(3000, 200))
	assert_object(plain.destination()).is_same(NavSystem.home_target())

# --- the pieces ---

func test_the_full_tank_is_the_heaviest_and_halves_acceleration() -> void:
	assert_float(Sections.DATA[Sections.FUEL_TANK]["mass"]).is_equal(3.0)
	for id in [Sections.SOLAR_ARRAY, Sections.DORSAL_ARM]:
		assert_float(Sections.DATA[id]["mass"]).is_less(Sections.DATA[Sections.FUEL_TANK]["mass"])

func test_a_section_carries_its_own_detail_and_plain_freight_none() -> void:
	var array := _piece(Sections.SOLAR_ARRAY, Transform2D.IDENTITY)
	var plain := Freight.spawn(_world, Vector2(200, 0))
	var lines := func(f: Freight) -> int:
		return f.get_node("Visual").get_children().filter(func(n): return n is Line2D).size()
	assert_int(lines.call(array)).is_greater(3)  # the cell grid, beside its edge and Lug
	assert_int(lines.call(plain)).is_equal(2)    # just its edge and its Lug
	assert_str(array.art).is_equal("array")

# --- seating ---

func test_seating_pulls_it_home_and_the_part_is_back() -> void:
	var m := _mount(Sections.FUEL_TANK)
	var tank := _piece(Sections.FUEL_TANK, m.global_transform * Transform2D(0.3, Vector2(-30, 10)))
	m.seat(tank)
	assert_bool(m.seated).is_true()
	assert_bool(m.is_seating()).is_true()
	assert_array(_sections(Sections.FUEL_TANK)).is_empty()  # no longer Freight: not saved, not marked
	await await_millis(int(Mount.SEAT_TIME * 1000.0) + 150)
	assert_bool(is_instance_valid(tank)).is_false()
	assert_bool(_part(Sections.FUEL_TANK).visible).is_true()
	await get_tree().process_frame
	assert_bool(_solid_at(m.position)).is_true()
	assert_object(NavSystem.get_target()).is_null()

func test_a_seated_mount_takes_nothing_more() -> void:
	var m := _mount(Sections.DORSAL_ARM)
	m.seat(_piece(Sections.DORSAL_ARM, m.global_transform))
	assert_bool(m.fits(_piece(Sections.DORSAL_ARM, m.global_transform))).is_false()

func test_the_pull_in_is_eased_and_about_half_a_second() -> void:
	assert_float(Mount.SEAT_TIME).is_between(0.4, 0.6)

# --- never lost ---

func test_an_empty_mount_leaves_its_section_floating_dead() -> void:
	var m := _mount(Sections.SOLAR_ARRAY)
	m.ensure_section()
	var found := _sections(Sections.SOLAR_ARRAY)
	assert_int(found.size()).is_equal(1)
	var array: Freight = found[0]
	assert_bool(array.lodged).is_true()
	assert_bool(array.handled).is_false()
	# No planet here, so it hangs in the station's frame
	assert_object(array.lodged_in).is_same(_station)
	assert_vector(array.global_position).is_equal_approx(_station.to_global(m.section_start_offset), Vector2(0.1, 0.1))

func test_each_section_starts_somewhere_of_its_own() -> void:
	# The tank hangs just past the dock, keeping pace with SR-7
	var tank := _mount(Sections.FUEL_TANK)
	assert_bool(tank.start_on_planet).is_false()
	assert_float(tank.section_start_offset.x).is_greater(1000.0)
	# The arm is adrift in Rook's ring (~2400-3600 out), going round with it
	var arm := _mount(Sections.DORSAL_ARM)
	assert_bool(arm.start_on_planet and arm.start_in_orbit and arm.start_beside_scrap).is_true()
	assert_float(arm.section_start_offset.length()).is_between(2400.0, 3600.0)
	# The array is buried in Rook's sunlit ground
	var array := _mount(Sections.SOLAR_ARRAY)
	assert_bool(array.start_on_planet and array.start_buried).is_true()

func test_the_ring_turns_faster_nearer_in() -> void:
	assert_float(OrbitalRingSpawner.angular_speed(10.0, 2500.0)).is_greater(OrbitalRingSpawner.angular_speed(10.0, 3500.0))
	assert_float(OrbitalRingSpawner.angular_speed(10.0, 1000.0)).is_equal_approx(0.1, 0.0001)

func test_a_section_adrift_in_a_ring_goes_round_with_it() -> void:
	_mount(Sections.DORSAL_ARM).ensure_section()
	var arm: Freight = _sections(Sections.DORSAL_ARM)[0]
	var anchor := Node2D.new()
	_world.add_child(anchor)
	anchor.global_position = Vector2(5000, 0)  # well clear of the station's hull
	arm.lodge_in(anchor, Vector2(300, 0), 1.0)
	for i in 30:
		await get_tree().physics_frame
	assert_float(arm.lodged_offset.angle()).is_greater(0.1)  # the ring's way round
	assert_float(arm.lodged_offset.length()).is_equal_approx(300.0, 0.5)
	assert_float(arm.global_position.distance_to(anchor.to_global(arm.lodged_offset))).is_less(12.0)

func test_the_section_is_never_left_twice() -> void:
	var m := _mount(Sections.FUEL_TANK)
	m.ensure_section()
	m.ensure_section()
	assert_int(_sections(Sections.FUEL_TANK).size()).is_equal(1)

func test_a_seated_mount_clears_a_stale_copy() -> void:
	var m := _mount(Sections.FUEL_TANK)
	m.ensure_section()
	m._show_seated(true)
	m.ensure_section()
	assert_array(_sections(Sections.FUEL_TANK)).is_empty()

func test_a_lodged_section_keeps_pace_with_what_it_is_lodged_in() -> void:
	_mount(Sections.DORSAL_ARM).ensure_section()
	var arm: Freight = _sections(Sections.DORSAL_ARM)[0]
	var anchor := Node2D.new()
	_world.add_child(anchor)
	anchor.global_position = Vector2(5000, 0)  # well clear of the station's hull
	arm.lodge_in(anchor, Vector2(100, 0))
	for i in 10:
		anchor.global_position += Vector2(4, 0)
		await get_tree().physics_frame
	await get_tree().physics_frame
	assert_float(arm.global_position.distance_to(anchor.global_position + Vector2(100, 0))).is_less(6.0)

func test_the_magnet_breaks_a_lodged_section_free() -> void:
	_mount(Sections.FUEL_TANK).ensure_section()
	var tank: Freight = _sections(Sections.FUEL_TANK)[0]
	tank.magnet_step(tank.global_transform.translated(Vector2(20, 0)), Vector2.ZERO)
	assert_bool(tank.lodged).is_false()

# --- saving ---

func test_a_section_row_keeps_its_shape_and_lodging() -> void:
	var tank := _piece(Sections.FUEL_TANK, Transform2D(0.4, Vector2(10, 20)))
	tank.lodge_in(_world, Vector2(-5, 7))
	var back := Freight.from_row(_world, tank.to_row())
	assert_str(back.section).is_equal(Sections.FUEL_TANK)
	assert_str(back.label).is_equal("FUEL TANK")
	assert_array(Array(back.outline)).is_equal(Array(tank.outline))
	assert_vector(back.lug_position).is_equal(tank.lug_position)
	assert_float(back.mass).is_equal(3.0)
	assert_bool(back.lodged).is_true()
	assert_vector(back.lodged_offset).is_equal(Vector2(-5, 7))

func test_a_plain_row_is_still_plain_freight() -> void:
	var back := Freight.from_row(_world, Freight.spawn(_world, Vector2.ZERO).to_row())
	assert_str(back.section).is_empty()
	assert_bool(back.lodged).is_false()

func test_a_saved_mast_from_before_the_rebuild_does_not_come_back() -> void:
	var rows := [{"section": "mast_1", "x": 1.0}, {"section": "", "x": 2.0}, {"section": Sections.FUEL_TANK, "x": 3.0}]
	Freight.restore_all(_world, rows)
	var ids := get_tree().get_nodes_in_group("freight").map(func(f): return f.section)
	assert_array(ids).contains_exactly_in_any_order(["", Sections.FUEL_TANK])

func test_seating_writes_the_seated_state_and_drops_the_piece_from_the_save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("wreck", "freight", [{"section": Sections.FUEL_TANK, "x": 1.0}, {"section": "", "x": 2.0}])
	cfg.save(SAVE_FILE)
	Save.save_seated_section(Sections.FUEL_TANK, PackedStringArray([Sections.FUEL_TANK]), SAVE_FILE)
	assert_array(Array(Save.load_seated_sections(SAVE_FILE))).contains_exactly([Sections.FUEL_TANK])
	var back := ConfigFile.new()
	back.load(SAVE_FILE)
	var rows: Array = back.get_value("wreck", "freight", [])
	assert_int(rows.size()).is_equal(1)
	assert_float(rows[0]["x"]).is_equal(2.0)

func test_seating_with_no_save_writes_nothing() -> void:
	Save.save_seated_section(Sections.FUEL_TANK, PackedStringArray([Sections.FUEL_TANK]), SAVE_FILE)
	assert_bool(FileAccess.file_exists(SAVE_FILE)).is_false()

func test_a_new_game_has_nothing_seated() -> void:
	var gs := auto_free(GameState.new()) as GameState
	gs.mark_section_seated(Sections.FUEL_TANK)
	assert_bool(gs.is_section_seated(Sections.FUEL_TANK)).is_true()
	gs.reset_all_state()
	assert_bool(gs.is_section_seated(Sections.FUEL_TANK)).is_false()

# --- the prompt ---

func test_the_prompt_reads_release_only_at_the_mount() -> void:
	assert_str(CarryingState.action_label(0.0, true)).is_equal("RELEASE")
	assert_str(CarryingState.action_label(0.0, false)).is_empty()
	assert_str(CarryingState.action_label(0.5, true)).starts_with("RELEASING")
	assert_str(CarryingState.action_label(0.5, false)).starts_with("RELEASING")

# --- docking ---

func test_the_ship_docks_at_the_head_of_the_refuel_boom() -> void:
	var slide := _station.get_node("DockArm/Slide")
	var ports := slide.get_children().filter(func(n): return n is SpacePort)
	assert_int(ports.size()).is_equal(1)
	var port: SpacePort = ports[0]
	var head := Freight.bounds((slide.get_node("RefuelBoom") as Polygon2D).polygon)
	assert_float(port.position.x).is_greater(head.end.x)  # out past the boom's truss, at its head
	assert_float(port.position.y).is_between(head.position.y - 30.0, head.end.y + 30.0)

# --- SR-7 only ---

func test_the_sun_station_has_no_mounts_and_keeps_its_tower1() -> void:
	var sun := auto_free(load("res://entities/structures/SunStation.tscn").instantiate()) as Node2D
	_world.add_child(sun)
	assert_array(sun.get_children().filter(func(n): return n is Mount)).is_empty()
	assert_bool((sun.get_node("Visuals/Tower1") as Polygon2D).visible).is_true()
