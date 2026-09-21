extends GdUnitTestSuite

## Sonar resonance is the ship's always-on ping: hold `action` and rings go out, in any
## state that isn't tied up or dead. The states decide via ShipState.allows_sonar().

var _ship: Ship

func before_test() -> void:
	_ship = auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	add_child(_ship)
	await get_tree().physics_frame

func after_test() -> void:
	Input.action_release("action")

func _hold_action(held: bool) -> void:
	if held:
		Input.action_press("action")
	else:
		Input.action_release("action")
	await get_tree().physics_frame
	await get_tree().physics_frame

func test_ship_owns_a_sonar_pulse_from_the_start() -> void:
	assert_object(_ship.sonar).is_not_null()
	assert_object(_ship.get_node_or_null("SonarPulse")).is_same(_ship.sonar)
	assert_bool(_ship.sonar.emitting).is_false()

func test_holding_action_in_flight_pings_and_releasing_stops() -> void:
	assert_str(_ship.state_machine.get_current_state_name()).is_equal("FlyingState")
	await _hold_action(true)
	assert_bool(_ship.sonar.emitting).is_true()
	await _hold_action(false)
	assert_bool(_ship.sonar.emitting).is_false()

func test_a_ring_leaves_the_ship_on_the_bus_while_held() -> void:
	var pings: Array[Vector2] = []
	var on_ping := func(origin: Vector2) -> void: pings.append(origin)
	EventBus.sonar_pulsed.connect(on_ping)
	_ship.global_position = Vector2(300, -120)
	await _hold_action(true)
	# The first ring spawns on the first emitting frame; wait a little past one interval
	# so at least one has certainly gone out.
	await get_tree().create_timer(SonarPulse.INTERVAL * 0.5).timeout
	EventBus.sonar_pulsed.disconnect(on_ping)
	assert_int(pings.size()).is_greater_equal(1)
	assert_that(pings[0]).is_equal(_ship.global_position)
	assert_int(_ship.sonar.ring_count()).is_greater_equal(1)

func test_free_states_allow_sonar_and_tied_up_states_refuse_it() -> void:
	var states: Dictionary = _ship.state_machine.states
	for free in ["FlyingState", "HarvestingState", "PlanetLandedState"]:
		assert_bool((states[free] as ShipState).allows_sonar()).override_failure_message(free).is_true()
	for busy in ["LandedState", "GateDockedState", "StrandedState", "DestroyedState", "ConsumedState"]:
		assert_bool((states[busy] as ShipState).allows_sonar()).override_failure_message(busy).is_false()

func test_a_state_that_refuses_sonar_keeps_the_key_from_it() -> void:
	# StrandedState only radios an offer on enter; safe to enter cold.
	_ship.state_machine.change_state("StrandedState")
	await _hold_action(true)
	assert_bool(_ship.wants_sonar()).is_false()
	assert_bool(_ship.sonar.emitting).is_false()
	RobotRadio.silence()
