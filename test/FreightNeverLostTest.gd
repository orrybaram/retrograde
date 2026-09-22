extends GdUnitTestSuite

## Freight is never lost (docs/adr/0012): saved where it is, stopped at the Void's edge,
## marked and tracked once handled, and kept on a hull abandoned while carrying it.

const EDGE := 340_000.0

var _world: Node2D
var _ship: Ship
var _home: Node2D

func before_test() -> void:
	_world = auto_free(Node2D.new()) as Node2D
	add_child(_world)
	_home = Node2D.new()
	_home.add_to_group("space_stations")
	_world.add_child(_home)
	_ship = load("res://entities/Ship/Ship.tscn").instantiate() as Ship
	_world.add_child(_ship)

func after_test() -> void:
	Freight.clear_all(get_tree())
	DerelictShip.clear_all(get_tree())
	InventoryManager.clear_inventory()
	NavSystem.track_home()

func _piece(pos := Vector2(500, 0)) -> Freight:
	return Freight.spawn(_world, pos)

func _pieces() -> Array:
	return get_tree().get_nodes_in_group("freight").filter(func(n): return not n.is_queued_for_deletion())

# --- the Void ---

func test_loose_freight_goes_on_well_inside_the_edge() -> void:
	assert_array(Freight.held_at_edge(Vector2(EDGE - 500.0, 0), Vector2(300, 0), Vector2.ZERO)).is_empty()

func test_loose_freight_is_stopped_just_inside_the_edge() -> void:
	var held := Freight.held_at_edge(Vector2(EDGE - 2.0, 0), Vector2(300, 0), Vector2.ZERO)
	assert_array(held).has_size(1)
	assert_float((held[0] as Vector2).length()).is_equal_approx(Freight.VOID_STOP_RADIUS, 0.01)
	assert_float(Freight.VOID_STOP_RADIUS).is_less(EDGE)

func test_freight_at_the_edge_may_still_head_back_in() -> void:
	assert_array(Freight.held_at_edge(Vector2(EDGE - 2.0, 0), Vector2(-50, 0), Vector2.ZERO)).is_empty()

func test_freight_let_go_past_the_edge_stops_where_it_is() -> void:
	var at := Vector2(0, EDGE + 900.0)
	var held := Freight.held_at_edge(at, Vector2(0, 40), Vector2.ZERO)
	assert_vector(held[0]).is_equal(at)

func test_freight_past_the_edge_may_still_head_back_in() -> void:
	assert_array(Freight.held_at_edge(Vector2(0, EDGE + 900.0), Vector2(0, -40), Vector2.ZERO)).is_empty()

func test_the_edge_is_measured_from_the_sun() -> void:
	var sun := Vector2(1000, 1000)
	assert_array(Freight.held_at_edge(sun + Vector2(EDGE - 2.0, 0), Vector2(1, 0), sun)).has_size(1)
	assert_array(Freight.held_at_edge(Vector2(EDGE - 2.0, 0), Vector2(1, 0), sun)).is_empty()

func test_the_void_returns_a_load_a_kilometre_inside_on_the_same_bearing() -> void:
	var sun := Vector2(500, -200)
	var at := Freight.void_return_point(sun + Vector2(3, 4).normalized() * (EDGE + 20000.0), sun)
	assert_float(at.distance_to(sun)).is_equal_approx(EDGE - 1000.0, 0.1)
	assert_vector((at - sun).normalized()).is_equal_approx(Vector2(0.6, 0.8), Vector2(0.0001, 0.0001))

func test_a_ship_crossing_the_edge_keeps_its_load() -> void:
	var f := _piece()
	_ship.clamp_freight(f, true)
	_ship.global_position = Vector2(EDGE + 500.0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(_ship.is_carrying()).is_true()

func test_the_void_takes_the_ship_but_hands_the_load_back() -> void:
	var f := _piece()
	_ship.state_machine.change_state("CarryingState")
	_ship.clamp_freight(f, true)
	_ship.global_position = Vector2(0, EDGE + 5000.0)
	_ship.state_machine.change_state("ConsumedState")
	assert_bool(_ship.is_carrying()).is_false()
	assert_bool(f.is_loose()).is_true()
	assert_float(f.global_position.length()).is_equal_approx(EDGE - 1000.0, 0.1)
	assert_float(f.global_position.normalized().y).is_greater(0.9999)  # the same bearing it was carried on
	assert_vector(f.linear_velocity).is_equal(Vector2.ZERO)
	assert_bool(f.is_marked()).is_true()
	assert_object(NavSystem.get_target()).is_same(f.tracking_target())

# --- marked and tracked ---

func test_untouched_freight_has_no_mark() -> void:
	var f := _piece()
	assert_bool(f.handled).is_false()
	assert_bool(f.is_marked()).is_false()
	assert_array(SystemMap.freight_marks(get_tree())).is_empty()

func test_clamping_tracks_home_and_letting_go_marks_and_tracks_the_piece() -> void:
	var f := _piece()
	NavSystem.track_point(Vector2(9000, 9000), "WAYPOINT")
	_ship.clamp_freight(f, true)
	assert_bool(f.handled).is_true()
	assert_bool(f.is_marked()).is_false()
	assert_bool(NavSystem.is_tracking_home()).is_true()

	NavSystem.track_point(Vector2(9000, 9000), "WAYPOINT")
	_ship.release_freight()
	assert_bool(f.is_marked()).is_true()
	assert_object(NavSystem.get_target()).is_same(f.tracking_target())
	var marks := SystemMap.freight_marks(get_tree())
	assert_array(marks).has_size(1)
	assert_str(marks[0]["label"]).is_equal(f.label)

	_ship.clamp_freight(f, true)
	assert_bool(f.is_marked()).is_false()
	assert_array(SystemMap.freight_marks(get_tree())).is_empty()
	assert_bool(NavSystem.is_tracking_home()).is_true()

func test_the_magnet_only_takes_loose_freight() -> void:
	var f := _piece()
	_ship.clamp_freight(f, true)
	var flying := _ship.state_machine.states["FlyingState"] as FlyingState
	assert_object(flying.freight_in_reach()).is_null()

# --- saving ---

func test_loose_freight_round_trips_where_it_is() -> void:
	var f := Freight.spawn(_world, Vector2(1200, -300), 0.7, Vector2(15, -4))
	f.handled = true
	var rows := Freight.snapshot_all(get_tree())
	assert_array(rows).has_size(1)
	Freight.clear_all(get_tree())
	assert_object(Freight.restore_all(_world, rows)).is_null()
	var back := _pieces()
	assert_array(back).has_size(1)
	var r := back[0] as Freight
	assert_vector(r.global_position).is_equal_approx(Vector2(1200, -300), Vector2(0.01, 0.01))
	assert_float(r.global_rotation).is_equal_approx(0.7, 0.001)
	assert_vector(r.linear_velocity).is_equal_approx(Vector2(15, -4), Vector2(0.01, 0.01))
	assert_bool(r.handled).is_true()

func test_repeated_reloads_never_duplicate_or_lose_freight() -> void:
	_piece(Vector2(100, 0))
	_piece(Vector2(-100, 0))
	for i in 3:
		var rows := Freight.snapshot_all(get_tree())
		Freight.clear_all(get_tree())
		Freight.restore_all(_world, rows)
	assert_array(_pieces()).has_size(2)

func test_a_clamped_load_is_saved_clamped_and_handed_back() -> void:
	var f := _piece()
	_ship.clamp_freight(f, true)
	var rows := Freight.snapshot_all(get_tree())
	assert_bool(rows[0]["clamped"]).is_true()
	Freight.clear_all(get_tree())
	assert_bool(_ship.is_carrying()).is_false()
	var clamped := Freight.restore_all(_world, rows)
	assert_object(clamped).is_not_null()
	_ship.clamp_freight(clamped, true)
	assert_bool(_ship.is_carrying()).is_true()
	assert_array(_pieces()).has_size(1)

# --- abandoned while carrying ---

func test_a_ship_stranded_with_a_load_keeps_it() -> void:
	_ship.state_machine.change_state("CarryingState")
	_ship.clamp_freight(_piece(), true)
	_ship.state_machine.change_state("StrandedState")
	assert_bool(_ship.is_carrying()).is_true()
	_ship.state_machine.change_state("FlyingState")
	assert_bool(_ship.is_carrying()).is_false()

func test_abandoning_while_carrying_leaves_the_load_on_the_hull() -> void:
	var f := _piece()
	_ship.clamp_freight(f, true)
	var d := DerelictShip.abandon(_ship)
	assert_bool(_ship.is_carrying()).is_false()
	assert_bool(d.is_holding_freight()).is_true()
	assert_bool(f.is_aboard_derelict()).is_true()
	assert_bool(f.is_marked()).is_false()
	assert_object(NavSystem.get_target()).is_same(d.tracking_target())
	var marks := SystemMap.freight_marks(get_tree())
	assert_array(marks).has_size(1)
	assert_bool(marks[0]["hull"]).is_true()
	assert_str(marks[0]["label"]).contains(f.label)

func test_a_derelict_without_freight_is_unmarked() -> void:
	DerelictShip.abandon(_ship)
	assert_array(SystemMap.freight_marks(get_tree())).is_empty()

func test_a_hull_holding_freight_damps_to_a_full_stop() -> void:
	var v := Vector2(200, 0)
	for i in 600:
		v = DerelictShip.damped_drift(v, 1.0 / 30.0, true)
	assert_vector(v).is_equal(Vector2.ZERO)
	var empty := Vector2(200, 0)
	for i in 600:
		empty = DerelictShip.damped_drift(empty, 1.0 / 30.0, false)
	assert_float(empty.length()).is_equal_approx(DerelictShip.RESIDUAL_DRIFT, 0.5)

func test_a_hull_holding_freight_round_trips_with_it() -> void:
	var f := _piece()
	_ship.clamp_freight(f, true)
	var d := DerelictShip.abandon(_ship)
	var at := f.global_position
	var rows := DerelictShip.snapshot_all(get_tree())
	assert_array(Freight.snapshot_all(get_tree())).is_empty()
	DerelictShip.clear_all(get_tree())
	Freight.clear_all(get_tree())
	await get_tree().process_frame
	DerelictShip.restore_all(_world, _ship.ship_polygon, rows)
	var back := get_tree().get_nodes_in_group("derelicts")
	assert_array(back).has_size(1)
	var r := back[0] as DerelictShip
	assert_bool(r.is_holding_freight()).is_true()
	assert_vector(r.freight.global_position).is_equal_approx(at, Vector2(0.05, 0.05))
	assert_array(_pieces()).has_size(1)

func test_salvaging_the_hull_frees_the_freight_beside_it() -> void:
	var f := _piece()
	_ship.clamp_freight(f, true)
	var d := DerelictShip.abandon(_ship)
	var at := f.global_position
	d.resource_depleted.emit()
	assert_bool(d.is_holding_freight()).is_false()
	assert_bool(f.is_loose()).is_true()
	assert_bool(f.is_marked()).is_true()
	assert_vector(f.global_position).is_equal_approx(at, Vector2(0.05, 0.05))
	assert_vector(f.linear_velocity).is_equal(Vector2.ZERO)
	assert_object(NavSystem.get_target()).is_same(f.tracking_target())

# --- drag ---

func test_loose_freight_bleeds_a_trace_of_speed() -> void:
	var f := Freight.spawn(_world, Vector2(2000, 0), 0.0, Vector2(1000, 0))
	assert_float(f.linear_damp).is_equal_approx(Freight.DRAG, 0.0001)
	assert_float(Freight.DRAG).is_greater(0.0)
	assert_float(Freight.DRAG).is_less_equal(0.02)  # a trace: an ordinary release barely notices
	# A piece let go of at boost speed gets below a ship's cruise speed in a few minutes
	var seconds_to_cruise := log(1000.0 / 300.0) / Freight.DRAG
	assert_float(seconds_to_cruise).is_less(180.0)
