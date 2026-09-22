extends Node
class_name StateMachine

## Generic state machine controller that manages state transitions.
## Auto-discovers child nodes that extend State as available states.

signal state_changed(from_state: State, to_state: State)

## The currently active state
var current_state: State = null

## The state being changed to, while the current one exits (null otherwise)
var next_state: State = null

## Dictionary mapping state names to State nodes
var states: Dictionary = {}

## Reference to the parent entity (set automatically)
var entity: Node = null

## Optional: override the initial state name. Falls back to FlyingState, then first discovered state.
@export var initial_state_name: String = ""

func _ready() -> void:
	# Get reference to parent entity
	entity = get_parent()

	# Auto-discover child state nodes
	_discover_states()

	# Set entity reference on all states
	for state in states.values():
		if state is State:
			state.entity = entity

	# Start with initial_state_name if set, FlyingState if available, otherwise first state
	if not states.is_empty():
		if initial_state_name != "" and states.has(initial_state_name):
			change_state(initial_state_name)
		elif states.has("FlyingState"):
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
	next_state = new_state
	if current_state:
		current_state.exit()
	next_state = null
	
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
