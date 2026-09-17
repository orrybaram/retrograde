extends GdUnitTestSuite

## Tests for StateMachine state discovery and transitions.


func _make_machine(state_names: Array[String], initial := "") -> StateMachine:
	var entity := Node.new()
	var machine := StateMachine.new()
	machine.initial_state_name = initial
	for state_name in state_names:
		var state := State.new()
		state.name = state_name
		machine.add_child(state)
	entity.add_child(machine)
	add_child(auto_free(entity))
	return machine


func test_starts_in_first_state_by_default() -> void:
	var machine := _make_machine(["IdleState", "DockedState"])
	assert_str(machine.get_current_state_name()).is_equal("IdleState")


func test_prefers_flying_state() -> void:
	var machine := _make_machine(["IdleState", "FlyingState"])
	assert_str(machine.get_current_state_name()).is_equal("FlyingState")


func test_initial_state_name_overrides_default() -> void:
	var machine := _make_machine(["FlyingState", "DockedState"], "DockedState")
	assert_str(machine.get_current_state_name()).is_equal("DockedState")


func test_states_get_entity_reference() -> void:
	var machine := _make_machine(["IdleState"])
	assert_object(machine.states["IdleState"].entity).is_same(machine.get_parent())


func test_change_state_calls_exit_and_enter() -> void:
	var machine := _make_machine(["FlyingState", "DockedState"])
	var flying: State = machine.states["FlyingState"]
	var docked: State = machine.states["DockedState"]
	var exited := [false]
	var entered := [false]
	flying.state_exited.connect(func(): exited[0] = true)
	docked.state_entered.connect(func(): entered[0] = true)

	machine.change_state("DockedState")

	assert_bool(exited[0]).is_true()
	assert_bool(entered[0]).is_true()
	assert_str(machine.get_current_state_name()).is_equal("DockedState")


func test_change_state_emits_state_changed() -> void:
	var machine := _make_machine(["FlyingState", "DockedState"])
	var flying: State = machine.states["FlyingState"]
	var docked: State = machine.states["DockedState"]
	var args := []
	machine.state_changed.connect(func(from, to): args.append_array([from, to]))

	machine.change_state("DockedState")

	assert_array(args).contains_exactly([flying, docked])


func test_change_to_unknown_state_keeps_current() -> void:
	var machine := _make_machine(["FlyingState"])
	machine.change_state("NopeState")
	assert_str(machine.get_current_state_name()).is_equal("FlyingState")
