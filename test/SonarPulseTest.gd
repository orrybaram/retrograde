extends GdUnitTestSuite

## Sonar resonance is the ship's always-on ping: tap `action` and one ring goes out; hold it
## and the one ring reaches further, in any state that isn't tied up or dead. The states
## decide via ShipState.allows_sonar().

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
	assert_bool(_ship.sonar.charging).is_false()

func test_holding_charges_and_letting_go_sends_one_ring() -> void:
	assert_str(_ship.state_machine.get_current_state_name()).is_equal("FlyingState")
	await _hold_action(true)
	assert_bool(_ship.sonar.charging).is_true()
	assert_int(_ship.sonar.ring_count()).is_equal(0)
	await _hold_action(false)
	assert_bool(_ship.sonar.charging).is_false()
	assert_int(_ship.sonar.ring_count()).is_equal(1)

func test_a_ring_leaves_the_ship_on_the_bus_when_let_go() -> void:
	var pings: Array[Vector2] = []
	var on_ping := func(origin: Vector2) -> void: pings.append(origin)
	EventBus.sonar_pulsed.connect(on_ping)
	_ship.global_position = Vector2(300, -120)
	await _hold_action(true)
	await _hold_action(false)
	EventBus.sonar_pulsed.disconnect(on_ping)
	assert_int(pings.size()).is_equal(1)
	assert_that(pings[0]).is_equal(_ship.global_position)

func test_a_tap_is_an_ordinary_ring() -> void:
	assert_float(SonarPulse.strength_for(0.0)).is_equal(1.0)

func test_a_longer_hold_reaches_further_without_a_ceiling() -> void:
	assert_float(SonarPulse.strength_for(SonarPulse.CHARGE_TIME)).is_equal_approx(2.0, 0.001)
	assert_float(SonarPulse.strength_for(SonarPulse.CHARGE_TIME * 10.0)).is_equal_approx(11.0, 0.001)

func test_a_stronger_ring_reaches_what_an_ordinary_one_cannot() -> void:
	var d := SonarPulse.END_RADIUS * 1.5
	assert_float(SonarPulse.time_to_reach(d)).is_equal(-1.0)
	assert_float(SonarPulse.time_to_reach(d, 2.0)).is_greater(0.0)

func test_free_states_allow_sonar_and_tied_up_states_refuse_it() -> void:
	var states: Dictionary = _ship.state_machine.states
	for free in ["FlyingState", "HarvestingState", "PlanetLandedState"]:
		assert_bool((states[free] as ShipState).allows_sonar()).override_failure_message(free).is_true()
	for busy in ["LandedState", "GateDockedState", "StrandedState", "DestroyedState", "ConsumedState", "CarryingState"]:
		assert_bool((states[busy] as ShipState).allows_sonar()).override_failure_message(busy).is_false()

func test_a_state_that_refuses_sonar_keeps_the_key_from_it() -> void:
	# StrandedState only radios an offer on enter; safe to enter cold.
	_ship.state_machine.change_state("StrandedState")
	await _hold_action(true)
	assert_bool(_ship.wants_sonar()).is_false()
	assert_bool(_ship.sonar.charging).is_false()
	await _hold_action(false)
	assert_int(_ship.sonar.ring_count()).is_equal(0)
	RobotRadio.silence()

func test_a_charge_the_key_is_taken_from_is_dropped_not_fired() -> void:
	await _hold_action(true)
	assert_bool(_ship.sonar.charging).is_true()
	_ship.state_machine.change_state("StrandedState")
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(_ship.sonar.charging).is_false()
	assert_int(_ship.sonar.ring_count()).is_equal(0)
	RobotRadio.silence()

func test_a_hold_that_was_refused_stays_ignored_until_let_go() -> void:
	# Holding through a state that refuses the ping (here stranded; in play, the hold that
	# lets Freight go) and back into flight: the rest of that hold charges nothing.
	_ship.state_machine.change_state("StrandedState")
	await _hold_action(true)
	_ship.state_machine.change_state("FlyingState")
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(_ship.sonar.charging).is_false()
	await _hold_action(false)
	assert_int(_ship.sonar.ring_count()).is_equal(0)
	await _hold_action(true)
	assert_bool(_ship.sonar.charging).is_true()
	RobotRadio.silence()
