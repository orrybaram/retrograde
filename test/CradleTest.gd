extends GdUnitTestSuite

## SR-7's Cradle (docs/adr/0012, docs/OPENING.md §9): slung under the refuel boom, it takes
## a Component released into it, the way a Mount takes its Section, and keeps it there to
## be fitted. A clamped Component tracks it.

const SAVE_FILE := "user://cradle_test_save.cfg"

var _world: Node2D
var _station: SpaceStation
var _cradle: Cradle

func before_test() -> void:
	_world = auto_free(Node2D.new()) as Node2D
	add_child(_world)
	_station = load("res://entities/structures/SpaceStation.tscn").instantiate() as SpaceStation
	_world.add_child(_station)
	await get_tree().process_frame
	_cradle = Cradle.find(get_tree())
	_arm_out(true)

func after_test() -> void:
	Freight.clear_all(get_tree())
	NavSystem.track_home()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))

func _arm_out(on: bool) -> void:
	(_station.get_node("DockArm") as DockArm)._set_out(on)
	_cradle._update_shown()

func _bay(xf: Transform2D) -> Freight:
	var f := Freight.new()
	Components.apply(f, Components.CARGO_BAY)
	_world.add_child(f)
	f.global_transform = xf
	return f

func _game_state() -> GameState:
	var gs := auto_free(GameState.new()) as GameState
	add_child(gs)
	return gs

# --- where it is ---

func test_sr7_has_one_cradle_under_the_boom() -> void:
	assert_object(_cradle).is_not_null()
	assert_object(_cradle.get_parent()).is_same(_station)
	assert_int(get_tree().get_nodes_in_group("cradles").size()).is_equal(1)
	# Under the boom's root, outboard of the hull and clear of the dock's head
	assert_float(_cradle.position.y + Cradle.BOOM_Y).is_equal_approx(108.0, 1.0)
	assert_float(_cradle.position.x).is_between(126.0, 340.0)

func test_a_seated_cargo_bay_is_clear_of_the_hull() -> void:
	var outline := PackedVector2Array(Components.DATA[Components.CARGO_BAY]["outline"])
	var hull := (_station.get_node("CollisionShape2D") as CollisionPolygon2D).polygon
	for p in outline:
		assert_bool(Geometry2D.is_point_in_polygon(_cradle.transform * p, hull)).is_false()

func test_it_hangs_off_the_arm_and_is_not_there_while_the_arm_is_in() -> void:
	_arm_out(false)
	assert_bool(_cradle.visible).is_false()
	assert_object(Cradle.accepting(get_tree(), _bay(_cradle.seats()[0]))).is_null()

# --- what it takes ---

func test_a_component_released_in_tolerance_fits_either_way_round() -> void:
	assert_object(Cradle.accepting(get_tree(), _bay(_cradle.seats()[0] * Transform2D(0.2, Vector2(25, -10))))).is_same(_cradle)
	Freight.clear_all(get_tree())
	await get_tree().process_frame
	assert_object(Cradle.accepting(get_tree(), _bay(_cradle.global_transform * Transform2D(-0.2, Vector2(-20, 5))))).is_same(_cradle)

func test_out_of_tolerance_it_does_not_fit() -> void:
	assert_object(Cradle.accepting(get_tree(), _bay(_cradle.seats()[0] * Transform2D(0.0, Vector2(60, 0))))).is_null()
	assert_object(Cradle.accepting(get_tree(), _bay(_cradle.seats()[0] * Transform2D(deg_to_rad(45.0), Vector2.ZERO)))).is_null()

func test_only_a_component_goes_in_the_cradle() -> void:
	var plain := Freight.spawn(_world, _cradle.global_position, _cradle.global_rotation)
	assert_object(Cradle.accepting(get_tree(), plain)).is_null()
	var tank := Freight.spawn_section(_world, Sections.FUEL_TANK, _cradle.global_position, _cradle.global_rotation)
	assert_object(Cradle.accepting(get_tree(), tank)).is_null()

func test_the_release_prompt_offers_the_cradle() -> void:
	var bay := _bay(_cradle.seats()[0])
	assert_object(CarryingState.home_for(get_tree(), bay)).is_same(_cradle)

# --- seating ---

func test_released_into_it_the_bay_is_pulled_home_and_stays() -> void:
	var bay := _bay(_cradle.seats()[0] * Transform2D(0.2, Vector2(-25, 12)))
	_cradle.seat(bay)
	assert_bool(_cradle.is_seating()).is_true()
	assert_bool(bay.is_in_group("freight")).is_false()  # the station's now: not saved, marked or swept
	assert_bool(bay.is_in_group("sonar_listeners")).is_false()
	assert_object(NavSystem.get_target()).is_null()
	await await_millis(int(Mount.SEAT_TIME * 1000.0) + 150)
	assert_bool(is_instance_valid(bay)).is_true()
	assert_object(bay.get_parent()).is_same(_cradle)
	assert_vector(bay.global_position).is_equal_approx(_cradle.global_position, Vector2(0.5, 0.5))
	assert_bool(bay.lug_facing_global().dot(Vector2.RIGHT.rotated(_station.global_rotation)) > 0.99).is_true()
	# It stays: nothing moves it on
	await await_millis(300)
	assert_vector(bay.global_position).is_equal_approx(_cradle.global_position, Vector2(0.5, 0.5))

func test_a_full_cradle_takes_nothing_more() -> void:
	_cradle.seat(_bay(_cradle.seats()[0]))
	assert_bool(_cradle.fits(_bay(_cradle.seats()[0]))).is_false()

func test_seating_records_what_is_in_the_cradle() -> void:
	var gs := _game_state()
	var cfg := ConfigFile.new()
	cfg.set_value("wreck", "freight", [{"component": Components.CARGO_BAY}, {"section": Sections.FUEL_TANK}])
	cfg.save(SAVE_FILE)
	gs.cradled = Components.CARGO_BAY
	Save.save_cradled(gs.cradled, SAVE_FILE)
	assert_str(Save.load_cradled(SAVE_FILE)).is_equal(Components.CARGO_BAY)
	cfg.load(SAVE_FILE)
	# The loose copy is gone from the saved Freight, so a reload can't bring it back twice
	assert_array(cfg.get_value("wreck", "freight")).contains_exactly([{"section": Sections.FUEL_TANK}])

func test_a_save_from_before_the_cradle_has_it_empty() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "stores", 0)
	cfg.save(SAVE_FILE)
	assert_str(Save.load_cradled(SAVE_FILE)).is_empty()

func test_a_load_puts_the_bay_back_in_the_cradle() -> void:
	var gs := _game_state()
	gs.cradled = Components.CARGO_BAY
	_cradle.refresh()
	assert_bool(_cradle.is_full()).is_true()
	assert_str(_cradle.piece.component).is_equal(Components.CARGO_BAY)
	assert_vector(_cradle.piece.global_position).is_equal_approx(_cradle.global_position, Vector2(0.5, 0.5))
	assert_bool(_cradle.piece.is_in_group("freight")).is_false()
	# Refreshing again doesn't stack a second one
	var first := _cradle.piece
	_cradle.refresh()
	assert_object(_cradle.piece).is_same(first)
	# A new game empties it
	gs.reset_all_state()
	_cradle.refresh()
	assert_bool(_cradle.is_full()).is_false()

# --- tracking ---

func test_a_clamped_component_tracks_the_cradle() -> void:
	var bay := _bay(Transform2D(0.0, Vector2(3000, 0)))
	var target := bay.destination() as NodeTrackingTarget
	assert_object(target.node).is_same(_cradle)
	assert_str(target.get_label()).is_equal("CRADLE")
