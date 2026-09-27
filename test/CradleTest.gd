extends GdUnitTestSuite

## SR-7's Cradle (docs/adr/0012, docs/OPENING.md §9): the drop bay in the container strip,
## worked by the DORSAL ARM's claw (DorsalClaw). A Component let go of anywhere near the
## drop point, at any angle, is taken - recorded at once - carried round to the bay and
## taken below, where it waits to be fitted. The bay is always open. No arm, or no power,
## and nothing is taken.

const SAVE_FILE := "user://cradle_test_save.cfg"

var _world: Node2D
var _gs: GameState
var _station: SpaceStation
var _claw: DorsalClaw

func before_test() -> void:
	_world = auto_free(Node2D.new()) as Node2D
	add_child(_world)
	_gs = auto_free(GameState.new()) as GameState
	_gs.mark_station_whole()
	_gs.core_started = true
	add_child(_gs)
	_station = load("res://entities/structures/SpaceStation.tscn").instantiate() as SpaceStation
	_world.add_child(_station)
	await get_tree().process_frame
	_claw = Cradle.find(get_tree()) as DorsalClaw
	# Quick in tests: the same moves, a fraction of the time
	for t in ["reach_time", "swing_time", "set_time", "open_time", "stow_time", "sink_time", "reset_time"]:
		_claw.set(t, 0.02)

func after_test() -> void:
	Freight.clear_all(get_tree())
	NavSystem.track_home()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))

func _bay(xf: Transform2D) -> Freight:
	var f := Freight.new()
	Components.apply(f, Components.CARGO_BAY)
	_world.add_child(f)
	f.global_transform = xf
	return f

## The drop point, moved `offset` px (station frame) and turned `turn` from Lug outboard.
func _at_drop(offset := Vector2.ZERO, turn := 0.0) -> Transform2D:
	var drop := _claw.drop_pose()
	return Transform2D(drop.get_rotation() + turn, drop.origin + _station.global_transform.basis_xform(offset))

func _arm_home(on: bool) -> void:
	if on:
		_gs.mark_section_seated(Sections.DORSAL_ARM)
	else:
		_gs.seated_sections.erase(Sections.DORSAL_ARM)
	Mount.for_section(get_tree(), Sections.DORSAL_ARM).refresh()

func _state() -> String:
	return _claw.state_machine.get_current_state_name()

# --- where it is ---

func test_sr7s_one_cradle_is_the_dorsal_claw() -> void:
	assert_object(_claw).is_not_null()
	assert_object(_claw.get_parent()).is_same(_station)
	assert_int(get_tree().get_nodes_in_group("cradles").size()).is_equal(1)
	assert_str(_state()).is_equal("ClawStowed")

func test_a_load_at_the_drop_point_is_clear_of_the_hull() -> void:
	var outline := PackedVector2Array(Components.DATA[Components.CARGO_BAY]["outline"])
	var hull := (_station.get_node("CollisionShape2D") as CollisionPolygon2D).polygon
	var at := Transform2D(PI, _claw.drop_point)
	for p in outline:
		assert_bool(Geometry2D.is_point_in_polygon(at * p, hull)).is_false()

func test_the_bay_is_in_the_deck_between_the_turntable_and_the_right_mast() -> void:
	var deck := (_station.get_node("Visuals/Deck") as Polygon2D).polygon
	assert_bool(Geometry2D.is_point_in_polygon(Vector2(_claw.bay_left + 1.0, _claw.deck_y + 1.0), deck)).is_true()
	assert_bool(Geometry2D.is_point_in_polygon(Vector2(_claw.bay_right - 1.0, _claw.deck_y + 1.0), deck)).is_true()
	assert_float(_claw.bay_left).is_greater(24.0)   # past the turntable
	assert_float(_claw.bay_right).is_less(168.0)    # short of the right mast

func test_the_drop_point_and_the_bay_are_in_the_arms_reach() -> void:
	var reach := _claw.upper_length + _claw.fore_length
	var grip := _claw.drop_point + Vector2.LEFT * (DorsalClaw.half_length(null) + _claw.palm)
	assert_float(grip.distance_to(_claw.shoulder)).is_less(reach)
	assert_float(_claw.slot_wrist().distance_to(_claw.shoulder)).is_less(reach)

# --- what it takes ---

func test_it_takes_a_component_anywhere_in_the_catch_radius_at_any_angle() -> void:
	for pose: Array in [[Vector2.ZERO, 0.0], [Vector2(60, -50), 0.6], [Vector2(-40, 70), -1.1], [Vector2(20, 20), PI]]:
		var bay := _bay(_at_drop(pose[0], pose[1]))
		assert_object(Cradle.accepting(get_tree(), bay)).override_failure_message("taken at %s, turned %s" % pose).is_same(_claw)
		bay.free()

func test_out_of_the_catch_radius_it_does_not() -> void:
	assert_object(Cradle.accepting(get_tree(), _bay(_at_drop(Vector2(_claw.catch_radius + 10.0, 0))))).is_null()

func test_only_a_component_goes_in_the_cradle() -> void:
	var drop := _claw.drop_pose()
	assert_object(Cradle.accepting(get_tree(), Freight.spawn(_world, drop.origin, drop.get_rotation()))).is_null()
	assert_object(Cradle.accepting(get_tree(), Freight.spawn_section(_world, Sections.FUEL_TANK, drop.origin, drop.get_rotation()))).is_null()

func test_the_release_prompt_offers_the_cradle() -> void:
	assert_object(CarryingState.home_for(get_tree(), _bay(_at_drop()))).is_same(_claw)

func test_no_arm_and_nothing_is_taken() -> void:
	_arm_home(false)
	assert_bool(_claw.arm_home()).is_false()
	assert_object(Cradle.accepting(get_tree(), _bay(_at_drop()))).is_null()
	_arm_home(true)
	assert_object(Cradle.accepting(get_tree(), _bay(_at_drop()))).is_same(_claw)

func test_a_dead_core_takes_nothing() -> void:
	_gs.core_started = false
	assert_object(Cradle.accepting(get_tree(), _bay(_at_drop()))).is_null()
	assert_array(_claw.slope_lamps()).contains_exactly([Colors.MUSTARD_DARK, Colors.MUSTARD_DARK])

# --- taking it ---

func test_let_go_of_it_is_the_cradles_at_once_and_goes_below() -> void:
	var bay := _bay(_at_drop(Vector2(30, -20), 0.4))
	_claw.seat(bay)
	assert_array(_gs.cradled).contains_exactly([Components.CARGO_BAY])
	assert_bool(bay.is_in_group("freight")).is_false()  # the station's now: not saved, marked or swept
	assert_bool(bay.is_in_group("sonar_listeners")).is_false()
	assert_object(NavSystem.get_target()).is_null()
	assert_str(_state()).is_equal("ClawDelivering")
	assert_bool(_claw.is_full()).is_true()
	await await_millis(600)
	assert_bool(is_instance_valid(bay)).override_failure_message("gone below").is_false()
	assert_str(_state()).is_equal("ClawStowed")
	assert_bool(_claw.is_full()).override_failure_message("the pad is back up").is_false()

func test_the_bay_is_always_open() -> void:
	_claw.seat(_bay(_at_drop()))
	assert_bool(_claw.fits(_bay(_at_drop()))).override_failure_message("busy mid-delivery").is_false()
	await await_millis(600)
	var second := _bay(_at_drop())
	assert_object(Cradle.accepting(get_tree(), second)).is_same(_claw)
	_claw.seat(second)
	assert_array(_gs.cradled).contains_exactly([Components.CARGO_BAY, Components.CARGO_BAY])

func test_a_load_leaves_the_bay_ready() -> void:
	_claw.seat(_bay(_at_drop()))
	_claw.refresh()
	assert_bool(_claw.is_full()).is_false()
	assert_str(_state()).is_equal("ClawStowed")
	assert_array(_gs.cradled).contains_exactly([Components.CARGO_BAY])

# --- the glide slope lamps ---

func test_the_lamps_say_which_side_of_level_the_load_is() -> void:
	var ship := auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	_world.add_child(ship)
	var bay := _bay(Transform2D.IDENTITY)
	ship.clamp_freight(bay, true)
	var red := Colors.RUST_RED
	var green := Colors.SAGE
	for case: Array in [[-80.0, [red, green]], [0.0, [green, green]], [80.0, [green, red]]]:
		ship.global_transform = _at_drop(Vector2(250, case[0])) * bay.transform.affine_inverse()
		assert_array(_claw.slope_lamps()).override_failure_message("%s px below level" % case[0]).contains_exactly(case[1])
	ship.global_transform = _at_drop(Vector2(_claw.warn_radius + 50.0, 0)) * bay.transform.affine_inverse()
	assert_array(_claw.slope_lamps()).override_failure_message("far off: dark").contains_exactly([Colors.MUSTARD_DARK, Colors.MUSTARD_DARK])
	assert_bool(_claw.beam_on()).override_failure_message("far off: the bay is dark").is_false()
	ship.global_transform = _at_drop(Vector2(250, 0)) * bay.transform.affine_inverse()
	assert_bool(_claw.beam_on()).override_failure_message("near: the bay lights").is_true()

func test_with_nothing_coming_the_bay_is_dark() -> void:
	assert_bool(_claw.is_open()).is_true()
	assert_bool(_claw.beam_on()).is_false()
	assert_array(_claw.slope_lamps()).contains_exactly([Colors.MUSTARD_DARK, Colors.MUSTARD_DARK])

# --- saving ---

func test_what_is_waiting_is_saved_and_leaves_no_loose_copy() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("wreck", "freight", [{"component": Components.CARGO_BAY}, {"section": Sections.FUEL_TANK}])
	cfg.save(SAVE_FILE)
	Save.save_cradled(PackedStringArray([Components.CARGO_BAY]), SAVE_FILE)
	assert_array(Save.load_cradled(SAVE_FILE)).contains_exactly([Components.CARGO_BAY])
	cfg.load(SAVE_FILE)
	# The loose copy is gone from the saved Freight, so a reload can't bring it back twice
	assert_array(cfg.get_value("wreck", "freight")).contains_exactly([{"section": Sections.FUEL_TANK}])

func test_a_save_from_before_the_cradle_has_it_empty() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "stores", 0)
	cfg.save(SAVE_FILE)
	assert_array(Save.load_cradled(SAVE_FILE)).is_empty()

func test_a_save_from_the_one_component_cradle_still_loads() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("sections", "cradled", Components.CARGO_BAY)
	cfg.save(SAVE_FILE)
	assert_array(Save.load_cradled(SAVE_FILE)).contains_exactly([Components.CARGO_BAY])
	cfg.set_value("sections", "cradled", "")
	cfg.save(SAVE_FILE)
	assert_array(Save.load_cradled(SAVE_FILE)).is_empty()

# --- tracking ---

func test_a_clamped_component_tracks_the_drop_point() -> void:
	var bay := _bay(Transform2D(0.0, Vector2(3000, 0)))
	var target := bay.destination() as NodeTrackingTarget
	assert_vector(target.node.global_position).is_equal_approx(_claw.drop_pose().origin, Vector2(0.5, 0.5))
	assert_str(target.get_label()).is_equal("CRADLE")

# --- the arm as a Section ---

func test_the_folded_arm_is_what_the_mount_takes() -> void:
	var m := Mount.for_section(get_tree(), Sections.DORSAL_ARM)
	var part := (_station.get_node("Visuals/DorsalArm") as Polygon2D).polygon
	var outline := PackedVector2Array(Sections.DATA[Sections.DORSAL_ARM]["outline"])
	# The Section, seated at its Mount, is the part's footprint, a hair smaller (MountTest)
	var seated := m.transform * outline
	for i in outline.size():
		assert_float(seated[i].distance_to(part[i])).is_less(6.0)
	# And the arm, stowed, stands inside it
	var w := _claw.stow_wrist
	for p in [_claw.shoulder + Vector2(0, -8), _claw.elbow_for(w), w, w + Vector2(40, 30), w + Vector2(40, -30)]:
		assert_bool(Geometry2D.is_point_in_polygon(p, part)).override_failure_message("%s is inside the folded arm" % p).is_true()

func test_the_folded_arm_is_the_hardest_carry() -> void:
	var arm := Freight.box_inertia(PackedVector2Array(Sections.DATA[Sections.DORSAL_ARM]["outline"]), 1.0)
	for id in [Sections.FUEL_TANK, Sections.SOLAR_ARRAY]:
		assert_float(arm).is_greater(Freight.box_inertia(PackedVector2Array(Sections.DATA[id]["outline"]), 1.0))
