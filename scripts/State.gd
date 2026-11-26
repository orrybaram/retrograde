extends Node
class_name State

## Generic base state class that can be used by any entity with a state machine.
## Provides the interface for state behavior and lifecycle management.

signal state_entered
signal state_exited

## Reference to the parent entity node (set by StateMachine)
var entity: Node = null

## Called when entering this state
func enter() -> void:
	state_entered.emit()

## Called when exiting this state
func exit() -> void:
	state_exited.emit()

## Called every physics frame while this state is active
## Override in subclasses to implement state-specific physics behavior
func physics_process(_delta: float) -> void:
	pass

## Called during physics integration while this state is active
## Override in subclasses to implement state-specific physics integration
func integrate_forces(_state: PhysicsDirectBodyState2D) -> void:
	pass

## Called every frame while this state is active
## Override in subclasses to implement state-specific frame updates
func process(_delta: float) -> void:
	pass
