extends Node
class_name StateMachine

## Generic state machine controller that manages state transitions.
## Auto-discovers child nodes that extend State as available states.

signal state_changed(from_state: State, to_state: State)

## The currently active state
var current_state: State = null

## Dictionary mapping state names to State nodes
var states: Dictionary = {}

## Reference to the parent entity (set automatically)
var entity: Node = null

func _ready() -> void:
	# Get reference to parent entity
	entity = get_parent()
	
	# Auto-discover child state nodes
	_discover_states()
	
	# Set entity reference on all states
	for state in states.values():
		if state is State:
			state.entity = entity
	
	# Start with FlyingState if available, otherwise first state
	if not states.is_empty():
		if states.has("FlyingState"):
			change_state("FlyingState")
		else:
			var first_state_name = states.keys()[0]
			change_state(first_state_name)

## Discovers all child nodes that extend State class
func _discover_states() -> void:
	states.clear()
	
	for child in get_children():
		if child is State:
			states[child.name] = child

## Changes to a new state by name
func change_state(state_name: String) -> void:
	if not states.has(state_name):
		push_error("StateMachine: State '%s' not found" % state_name)
		return
	
	var new_state: State = states[state_name]
	
	# Exit current state
	if current_state:
		current_state.exit()
	
	# Store old state for signal
	var old_state = current_state
	
	# Enter new state
	current_state = new_state
	current_state.enter()
	
	# Emit signal
	state_changed.emit(old_state, current_state)

## Gets the current state name
func get_current_state_name() -> String:
	if current_state:
		return current_state.name
	return ""

## Checks if a state exists
func has_state(state_name: String) -> bool:
	return states.has(state_name)
