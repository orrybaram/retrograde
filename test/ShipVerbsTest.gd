extends GdUnitTestSuite

## The Ship's verbs for Freight and docking: each one owns its state change, so the ship
## is in CarryingState exactly while it holds Freight, and docks only through dock_at.

const EDGE := 340_000.0

## The smallest thing a ship can dock at: every method Dockable asks for, and nothing else.
const BERTH_SOURCE := """extends Node2D
var open := true
func get_dock_position() -> Vector2:
	return global_position
func get_dock_rotation() -> float:
	return global_rotation
func get_dock_distance() -> float:
	return 30.0
func get_dock_velocity() -> Vector2:
	return Vector2.ZERO
func accepts_docking() -> bool:
	return open
"""

var _world: Node2D
var _ship: Ship

func before_test() -> void:
	_world = auto_free(Node2D.new()) as Node2D
	add_child(_world)
	_ship = load("res://entities/Ship/Ship.tscn").instantiate() as Ship
	_world.add_child(_ship)

func after_test() -> void:
	Freight.clear_all(get_tree())
	InventoryManager.clear_inventory()
	NavSystem.track_home()

func _piece(pos := Vector2(500, 0)) -> Freight:
	return Freight.spawn(_world, pos)

func _state() -> String:
	return _ship.state_machine.get_current_state_name()

func _berth(pos := Vector2(2000, 0)) -> Node2D:
	var script := GDScript.new()
	script.source_code = BERTH_SOURCE
	script.reload()
	var berth := Node2D.new()
	berth.set_script(script)
	berth.add_to_group(Dockable.GROUP)
	berth.global_position = pos
	_world.add_child(berth)
	return berth

func _no_hand_over_meta() -> void:
	for key in ["pending_freight", "pending_dockable", "instant_dock"]:
		assert_bool(_ship.has_meta(key)).override_failure_message(key).is_false()

# --- carry ---

func test_carry_clamps_the_piece_and_flies_laden() -> void:
	var f := _piece()
	assert_bool(_ship.carry(f, true)).is_true()
	assert_str(_state()).is_equal("CarryingState")
	assert_object(_ship.freight).is_same(f)
	assert_object(f.get_parent()).is_same(_ship)
	_no_hand_over_meta()

func test_carry_takes_one_load_at_a_time() -> void:
	var first := _piece()
	var second := _piece(Vector2(-500, 0))
	_ship.carry(first, true)
	assert_bool(_ship.carry(second, true)).is_false()
	assert_object(_ship.freight).is_same(first)
	assert_bool(second.is_loose()).is_true()

func test_carry_with_nothing_stays_flying() -> void:
	assert_bool(_ship.carry(null)).is_false()
	assert_str(_state()).is_equal("FlyingState")
	assert_bool(_ship.is_carrying()).is_false()

func test_carrying_state_without_a_load_hands_straight_back_to_flight() -> void:
	_ship.state_machine.change_state("CarryingState")
	assert_str(_state()).is_equal("FlyingState")
	assert_bool(_ship.is_carrying()).is_false()

# --- let go ---

func test_let_go_leaves_the_piece_loose_and_flies_unladen() -> void:
	var f := _piece()
	_ship.carry(f, true)
	assert_object(_ship.let_go()).is_same(f)
	assert_str(_state()).is_equal("FlyingState")
	assert_bool(_ship.is_carrying()).is_false()
	assert_bool(f.is_loose()).is_true()
	assert_object(f.get_parent()).is_same(_world)

func test_let_go_with_nothing_on_does_nothing() -> void:
	assert_object(_ship.let_go()).is_null()
	assert_str(_state()).is_equal("FlyingState")

func test_leaving_carrying_any_other_way_lets_go_too() -> void:
	var f := _piece()
	_ship.carry(f, true)
	_ship.explode()
	assert_str(_state()).is_equal("DestroyedState")
	assert_bool(_ship.is_carrying()).is_false()
	assert_bool(f.is_loose()).is_true()

# --- surrender to the void ---

func test_surrender_to_the_void_puts_the_load_back_inside_the_edge() -> void:
	var f := _piece()
	_ship.carry(f, true)
	_ship.global_position = Vector2(EDGE + 5000.0, 0)
	assert_object(_ship.surrender_to_void()).is_same(f)
	assert_str(_state()).is_equal("ConsumedState")
	assert_bool(_ship.is_carrying()).is_false()
	assert_bool(f.is_loose()).is_true()
	assert_float(f.global_position.length()).is_equal_approx(EDGE - 1000.0, 0.1)

func test_surrender_with_nothing_on_is_still_consumed() -> void:
	assert_object(_ship.surrender_to_void()).is_null()
	assert_str(_state()).is_equal("ConsumedState")

# --- hand over ---

func test_hand_over_leaves_the_load_clamped_to_the_holder() -> void:
	var f := _piece()
	var hull := Node2D.new()
	_world.add_child(hull)
	_ship.carry(f, true)
	assert_object(_ship.hand_over(hull)).is_same(f)
	assert_str(_state()).is_equal("FlyingState")
	assert_bool(_ship.is_carrying()).is_false()
	assert_object(f.get_parent()).is_same(hull)
	assert_int(f.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)

# --- a load or a new game ---

func test_clearing_the_freight_leaves_the_ship_flying_unladen() -> void:
	_ship.carry(_piece(), true)
	Freight.clear_all(get_tree())
	assert_str(_state()).is_equal("FlyingState")
	assert_bool(_ship.is_carrying()).is_false()

func test_a_piece_freed_out_from_under_the_clamp_leaves_the_ship_flying() -> void:
	var f := _piece()
	_ship.carry(f, true)
	f.free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_str(_state()).is_equal("FlyingState")
	assert_bool(_ship.is_carrying()).is_false()
	assert_object(_ship.get_node_or_null("FreightCollision")).is_null()
	assert_float(_ship.turn_ratio()).is_equal(1.0)

# --- dock ---

func test_dock_at_a_port_docks_into_landed_state() -> void:
	var berth := _berth()
	_ship.global_position = berth.get_dock_position()
	assert_bool(_ship.dock_at(berth, true)).is_true()
	assert_str(_state()).is_equal("LandedState")
	assert_object((_ship.state_machine.current_state as LandedState).locked_dockable).is_same(berth)
	_no_hand_over_meta()

func test_dock_at_something_undockable_does_nothing() -> void:
	var rock := Node2D.new()
	_world.add_child(rock)
	assert_bool(_ship.dock_at(rock)).is_false()
	assert_bool(_ship.dock_at(null)).is_false()
	assert_str(_state()).is_equal("FlyingState")

func test_docked_states_entered_by_name_hand_straight_back_to_flight() -> void:
	_ship.state_machine.change_state("LandedState")
	assert_str(_state()).is_equal("FlyingState")

func test_docking_with_a_load_on_lets_it_go() -> void:
	var f := _piece()
	var berth := _berth()
	_ship.carry(f, true)
	_ship.dock_at(berth, true)
	assert_str(_state()).is_equal("LandedState")
	assert_bool(_ship.is_carrying()).is_false()
	assert_bool(f.is_loose()).is_true()

# --- the dockable interface ---

func test_a_dockable_has_every_method_the_interface_names() -> void:
	assert_bool(Dockable.is_dockable(_berth())).is_true()
	var bare := Node2D.new()
	_world.add_child(bare)
	assert_bool(Dockable.is_dockable(bare)).is_false()
	assert_bool(Dockable.is_dockable(null)).is_false()

func test_nearest_finds_the_closest_open_dock_in_reach() -> void:
	var near := _berth(Vector2(10, 0))
	var far := _berth(Vector2(25, 0))
	_berth(Vector2(500, 0))  # out of reach
	assert_object(Dockable.nearest(get_tree(), Vector2.ZERO)).is_same(near)
	near.set("open", false)
	assert_object(Dockable.nearest(get_tree(), Vector2.ZERO)).is_same(far)
	far.set("open", false)
	assert_object(Dockable.nearest(get_tree(), Vector2.ZERO)).is_null()

func test_approach_wants_slow_and_square() -> void:
	var berth := _berth()
	var square := Dockable.ship_rotation(berth)
	assert_bool(Dockable.approach_ok(berth, square, Vector2(10, 0), deg_to_rad(30.0))).is_true()
	assert_bool(Dockable.approach_ok(berth, square, Vector2(60, 0), deg_to_rad(30.0))).is_false()
	assert_bool(Dockable.approach_ok(berth, square + deg_to_rad(45.0), Vector2.ZERO, deg_to_rad(30.0))).is_false()
