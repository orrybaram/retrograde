extends GdUnitTestSuite

## Seating a Section (docs/adr/0012, docs/OPENING.md §2): MAST 1 goes back into its Mount
## on SR-7 where `Tower1` was, and only there.

const SAVE_FILE := "user://mount_test_save.cfg"

var _world: Node2D
var _station: SpaceStation
var _mount: Mount

func before_test() -> void:
	_world = auto_free(Node2D.new()) as Node2D
	add_child(_world)
	_station = load("res://entities/structures/SpaceStation.tscn").instantiate() as SpaceStation
	# As on SR-7 in scenes/HomeSystem.tscn
	_mount = Mount.new()
	_mount.name = "Mast1Mount"
	_mount.position = Vector2(0, -82.5)
	_mount.part = NodePath("../Visuals/Tower1")
	_mount.collision = NodePath("../CollisionShape2D")
	_station.add_child(_mount)
	_world.add_child(_station)
	await get_tree().process_frame

func after_test() -> void:
	Freight.clear_all(get_tree())
	NavSystem.track_home()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))

func _tower() -> Polygon2D:
	return _station.get_node("Visuals/Tower1") as Polygon2D

func _mast(xf: Transform2D) -> Freight:
	return Freight.spawn_section(_world, Sections.MAST_1, xf.origin, xf.get_rotation())

func _sections() -> Array:
	return get_tree().get_nodes_in_group("freight").filter(
		func(n): return not n.is_queued_for_deletion() and n.section == Sections.MAST_1)

func _solid_at(station_point: Vector2) -> bool:
	for child in _station.get_children():
		var c := child as CollisionPolygon2D
		if c and not c.disabled and c.is_inside_tree() \
				and Geometry2D.is_point_in_polygon(c.transform.affine_inverse() * station_point, c.polygon):
			return true
	return false

# --- the tear ---

func test_a_new_station_is_missing_tower1() -> void:
	assert_bool(_tower().visible).is_false()
	assert_bool(_mount.seated).is_false()

func test_the_mount_sits_where_tower1_shows_between_hub_and_core() -> void:
	assert_bool(Geometry2D.is_point_in_polygon(_mount.position, _tower().polygon)).is_true()
	assert_bool(_mount.in_tolerance(_mount.global_transform, _mount.global_transform)).is_true()

func test_what_showed_of_tower1_is_what_goes_missing() -> void:
	# Tower1 runs under the whole station; only its waist and its stem ever showed
	var gaps := Mount.exposed_regions(_tower().polygon, _mount._covers())
	assert_int(gaps.size()).is_equal(2)
	var boxes := gaps.map(func(g): return Freight.bounds(g))
	boxes.sort_custom(func(a, b): return a.position.y < b.position.y)
	assert_vector(boxes[0].position).is_equal_approx(Vector2(-50, -108), Vector2(0.5, 0.5))
	assert_vector(boxes[0].end).is_equal_approx(Vector2(50, -57), Vector2(0.5, 0.5))
	assert_vector(boxes[1].position).is_equal_approx(Vector2(-50, 124), Vector2(0.5, 0.5))

func test_the_torn_edges_are_where_tower1_met_the_station() -> void:
	var edges := Mount.torn_edges(Rect2(-50, -108, 100, 51), _mount._covers())
	var inward := edges.map(func(e): return e[2])
	assert_array(inward).contains_exactly_in_any_order([Vector2.DOWN, Vector2.UP])

func test_the_gap_is_not_a_wall_while_the_mount_is_empty() -> void:
	await get_tree().process_frame
	assert_bool(_solid_at(Vector2(0, -82.5))).is_false()
	assert_bool(_solid_at(Vector2(0, 160))).is_false()
	assert_bool(_solid_at(Vector2(0, -150))).is_true()  # the hub is still there
	assert_bool(_solid_at(Vector2(0, 20))).is_true()    # and the core

func test_cutting_a_hole_through_a_waist_splits_the_polygon() -> void:
	var bar := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 10), Vector2(0, 10)])
	var hole := PackedVector2Array([Vector2(40, -5), Vector2(60, -5), Vector2(60, 15), Vector2(40, 15)])
	assert_int(Mount.cut_polygon(bar, [hole]).size()).is_equal(2)

# --- fitting ---

func test_mast_1_fits_within_40px_and_30_degrees() -> void:
	var m := _mount.global_transform
	assert_bool(Mount.in_tolerance(m * Transform2D(0.0, Vector2(39, 0)), m)).is_true()
	assert_bool(Mount.in_tolerance(m * Transform2D(deg_to_rad(29), Vector2.ZERO), m)).is_true()
	assert_bool(Mount.in_tolerance(m * Transform2D(0.0, Vector2(0, 41)), m)).is_false()
	assert_bool(Mount.in_tolerance(m * Transform2D(deg_to_rad(31), Vector2.ZERO), m)).is_false()

func test_only_mast_1_fits_this_mount() -> void:
	var at := _mount.global_transform
	var other := Freight.spawn(_world, at.origin, at.get_rotation())
	assert_bool(_mount.fits(other)).is_false()
	assert_object(Mount.accepting(get_tree(), other)).is_null()
	var mast := _mast(at)
	assert_bool(_mount.fits(mast)).is_true()
	assert_object(Mount.accepting(get_tree(), mast)).is_same(_mount)

func test_mast_1_out_of_tolerance_does_not_fit() -> void:
	var mast := _mast(_mount.global_transform * Transform2D(0.0, Vector2(-60, 0)))
	assert_object(Mount.accepting(get_tree(), mast)).is_null()

func test_clamping_mast_1_tracks_its_mount() -> void:
	var mast := _mast(Transform2D(0.0, Vector2(3000, 0)))
	assert_object((mast.destination() as NodeTrackingTarget).node).is_same(_mount)
	assert_str(mast.destination().get_label()).is_equal("MOUNT")
	var plain := Freight.spawn(_world, Vector2(3000, 200))
	assert_object(plain.destination()).is_same(NavSystem.home_target())

# --- seating ---

func test_seating_pulls_it_home_and_tower1_is_back() -> void:
	var mast := _mast(_mount.global_transform * Transform2D(0.3, Vector2(-30, 10)))
	_mount.seat(mast)
	assert_bool(_mount.seated).is_true()
	assert_bool(_mount.is_seating()).is_true()
	assert_array(_sections()).is_empty()  # no longer Freight: not saved, not marked
	await await_millis(int(Mount.SEAT_TIME * 1000.0) + 150)
	assert_bool(is_instance_valid(mast)).is_false()
	assert_bool(_tower().visible).is_true()
	await get_tree().process_frame
	assert_bool(_solid_at(Vector2(0, -82.5))).is_true()
	assert_bool(NavSystem.is_tracking_home()).is_true()

func test_a_seated_mount_takes_nothing_more() -> void:
	_mount.seat(_mast(_mount.global_transform))
	assert_bool(_mount.fits(_mast(_mount.global_transform))).is_false()

func test_the_pull_in_is_eased_and_about_half_a_second() -> void:
	assert_float(Mount.SEAT_TIME).is_between(0.4, 0.6)

# --- never lost ---

func test_an_empty_mount_leaves_its_section_lodged_in_the_debris() -> void:
	_mount.ensure_section()
	var found := _sections()
	assert_int(found.size()).is_equal(1)
	var mast: Freight = found[0]
	assert_bool(mast.lodged).is_true()
	assert_object(mast.lodged_in).is_same(_world)  # the body the station circles
	assert_bool(mast.handled).is_false()
	assert_vector(mast.global_position).is_equal_approx(_world.global_position + _mount.section_start_offset, Vector2(0.1, 0.1))

func test_the_section_is_never_left_twice() -> void:
	_mount.ensure_section()
	_mount.ensure_section()
	assert_int(_sections().size()).is_equal(1)

func test_a_seated_mount_clears_a_stale_copy() -> void:
	_mount.ensure_section()
	_mount._show_seated(true)
	_mount.ensure_section()
	assert_array(_sections()).is_empty()

func test_a_lodged_section_keeps_pace_with_the_debris() -> void:
	_mount.ensure_section()
	var mast: Freight = _sections()[0]
	var anchor := Node2D.new()
	_world.add_child(anchor)
	mast.lodge_in(anchor, Vector2(100, 0))
	for i in 10:
		anchor.global_position += Vector2(4, 0)
		await get_tree().physics_frame
	await get_tree().physics_frame
	assert_float(mast.global_position.distance_to(anchor.global_position + Vector2(100, 0))).is_less(6.0)

func test_the_magnet_breaks_a_lodged_section_free() -> void:
	_mount.ensure_section()
	var mast: Freight = _sections()[0]
	mast.magnet_step(mast.global_transform.translated(Vector2(20, 0)), Vector2.ZERO)
	assert_bool(mast.lodged).is_false()

# --- saving ---

func test_a_section_row_keeps_its_shape_and_lodging() -> void:
	var mast := _mast(Transform2D(0.4, Vector2(10, 20)))
	mast.lodge_in(_world, Vector2(-5, 7))
	var back := Freight.from_row(_world, mast.to_row())
	assert_str(back.section).is_equal(Sections.MAST_1)
	assert_str(back.label).is_equal("MAST 1")
	assert_array(Array(back.outline)).is_equal(Array(mast.outline))
	assert_vector(back.lug_position).is_equal(mast.lug_position)
	assert_bool(back.lodged).is_true()
	assert_vector(back.lodged_offset).is_equal(Vector2(-5, 7))

func test_a_plain_row_is_still_plain_freight() -> void:
	var back := Freight.from_row(_world, Freight.spawn(_world, Vector2.ZERO).to_row())
	assert_str(back.section).is_empty()
	assert_bool(back.lodged).is_false()

func test_seating_writes_the_seated_state_and_drops_the_piece_from_the_save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("wreck", "freight", [{"section": Sections.MAST_1, "x": 1.0}, {"section": "", "x": 2.0}])
	cfg.save(SAVE_FILE)
	Save.save_seated_section(Sections.MAST_1, PackedStringArray([Sections.MAST_1]), SAVE_FILE)
	assert_array(Array(Save.load_seated_sections(SAVE_FILE))).contains_exactly([Sections.MAST_1])
	var back := ConfigFile.new()
	back.load(SAVE_FILE)
	var rows: Array = back.get_value("wreck", "freight", [])
	assert_int(rows.size()).is_equal(1)
	assert_float(rows[0]["x"]).is_equal(2.0)

func test_seating_with_no_save_writes_nothing() -> void:
	Save.save_seated_section(Sections.MAST_1, PackedStringArray([Sections.MAST_1]), SAVE_FILE)
	assert_bool(FileAccess.file_exists(SAVE_FILE)).is_false()

func test_a_new_game_has_nothing_seated() -> void:
	var gs := auto_free(GameState.new()) as GameState
	gs.mark_section_seated(Sections.MAST_1)
	assert_bool(gs.is_section_seated(Sections.MAST_1)).is_true()
	gs.reset_all_state()
	assert_bool(gs.is_section_seated(Sections.MAST_1)).is_false()

# --- the prompt ---

func test_the_prompt_reads_release_only_at_the_mount() -> void:
	assert_str(CarryingState.action_label(0.0, true)).is_equal("RELEASE")
	assert_str(CarryingState.action_label(0.0, false)).is_empty()
	assert_str(CarryingState.action_label(0.5, true)).starts_with("RELEASING")
	assert_str(CarryingState.action_label(0.5, false)).starts_with("RELEASING")

# --- SR-7 only ---

func test_the_sun_station_has_no_mount_and_keeps_its_tower1() -> void:
	var sun := auto_free(load("res://entities/structures/SunStation.tscn").instantiate()) as Node2D
	_world.add_child(sun)
	assert_object(sun.get_node_or_null("Mast1Mount")).is_null()
	assert_bool((sun.get_node("Visuals/Tower1") as Polygon2D).visible).is_true()
