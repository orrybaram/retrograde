extends GdUnitTestSuite

## SR-7's right solar wing (docs/OPENING.md §2): left hanging on its hinge, pushed home by
## the ship's hull - never clamped - and locked with a clunk once it is nearly true.

const SAVE_FILE := "user://array_nudge_test_save.cfg"

var _world: Node2D
var _station: SpaceStation
var _wing: ArrayNudge

func before_test() -> void:
	_world = auto_free(Node2D.new()) as Node2D
	add_child(_world)
	_station = load("res://entities/structures/SpaceStation.tscn").instantiate() as SpaceStation
	_world.add_child(_station)
	_wing = _station.get_node("ArrayNudge") as ArrayNudge
	await get_tree().process_frame

func after_test() -> void:
	Freight.clear_all(get_tree())

func test_a_new_game_leaves_it_hanging_off_true() -> void:
	assert_bool(_wing.seated).is_false()
	assert_float(_wing.off_true()).is_equal_approx(ArrayNudge.HANG_ANGLE, 0.001)

func test_it_hangs_off_the_keel_beside_the_missing_wing() -> void:
	var gap := _station.get_node("SolarArrayMount") as Mount
	assert_float(_wing.position.y).is_equal_approx(gap.position.y, 0.5)
	assert_float(_wing.position.x).is_greater(0.0)
	assert_float(gap.position.x).is_less(0.0)

func test_pushing_the_tip_back_turns_it_toward_true() -> void:
	# Hanging clockwise, tip down: pushing up under the tip turns it back
	var off := ArrayNudge.HANG_ANGLE
	var tip := Vector2(140, 0).rotated(off)
	var after := ArrayNudge.push_step(off, Vector2.ZERO, tip, Vector2(0, -80), 0.1)
	assert_float(after).is_less(off)
	assert_float(after).is_greater(0.0)

func test_pushing_it_the_wrong_way_does_nothing() -> void:
	var off := ArrayNudge.HANG_ANGLE
	var tip := Vector2(140, 0).rotated(off)
	assert_float(ArrayNudge.push_step(off, Vector2.ZERO, tip, Vector2(0, 80), 0.1)).is_equal(off)

func test_it_never_turns_past_true_or_faster_than_its_cap() -> void:
	var tip := Vector2(140, 0)
	var fast := ArrayNudge.push_step(0.1, Vector2.ZERO, tip, Vector2(0, -5000), 0.05)
	assert_float(fast).is_equal_approx(0.1 - ArrayNudge.MAX_TURN_SPEED * 0.05, 0.0001)
	assert_float(ArrayNudge.push_step(0.01, Vector2.ZERO, tip, Vector2(0, -5000), 1.0)).is_equal(0.0)

func test_a_push_at_the_hinge_turns_nothing() -> void:
	assert_float(ArrayNudge.push_step(0.3, Vector2.ZERO, Vector2(0.2, 0.2), Vector2(0, -100), 0.1)).is_equal(0.3)

func test_the_ship_presses_on_it_only_up_close() -> void:
	var tip := _wing.to_global(Vector2(140, 0))
	assert_bool(_wing.is_pressing(tip + _wing.global_transform.basis_xform(Vector2(0, 30)))).is_true()
	assert_bool(_wing.is_pressing(tip + _wing.global_transform.basis_xform(Vector2(0, 80)))).is_false()

func test_thrusting_into_it_counts_as_a_push() -> void:
	var ship := auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	ship.global_rotation = -PI / 2.0  # nose up
	ship.want_thrust = true
	var push := ArrayNudge.ship_push(ship, Vector2.ZERO)
	assert_vector(push).is_equal_approx(Vector2(0, -ArrayNudge.THRUST_PUSH), Vector2(0.01, 0.01))
	ship.want_thrust = false
	ship.want_reverse_thrust = true
	assert_float(ArrayNudge.ship_push(ship, Vector2.ZERO).y).is_greater(0.0)

func test_locking_swings_it_true_and_it_stays_seated() -> void:
	var gs := auto_free(GameState.new()) as GameState
	gs.add_to_group("game_state")
	add_child(gs)
	_wing.lock()
	assert_bool(_wing.seated).is_true()
	assert_bool(gs.is_section_seated(Sections.SOLAR_ARRAY_2)).is_true()
	await await_millis(int(ArrayNudge.LOCK_TIME * 1000.0) + 150)
	assert_float(absf(_wing.off_true())).is_less(0.001)
	# Seated walls it off from further pushes
	_wing._physics_process(0.1)
	assert_float(absf(_wing.off_true())).is_less(0.001)

func test_a_seated_save_puts_it_back_true() -> void:
	var gs := auto_free(GameState.new()) as GameState
	gs.add_to_group("game_state")
	add_child(gs)
	gs.mark_section_seated(Sections.SOLAR_ARRAY_2)
	_wing.refresh()
	assert_bool(_wing.seated).is_true()
	assert_float(absf(_wing.off_true())).is_less(0.001)
	gs.seated_sections.clear()
	_wing.refresh()
	assert_float(_wing.off_true()).is_equal_approx(ArrayNudge.HANG_ANGLE, 0.001)

func test_it_is_not_freight() -> void:
	assert_bool(_wing.is_in_group("freight")).is_false()
	assert_bool(Sections.exists(Sections.SOLAR_ARRAY_2)).is_false()
