extends ShipState
class_name DockingState

## A state the ship is docked in: LandedState at a port, GateDockedState at a Gate. The
## only way in is Ship.dock_at, which stages the berth here before the transition, so
## enter() always knows what it is docking at. Entered any other way there is nothing
## staged, and the state hands straight back to flight.

var _staged_dockable: Node2D = null
var _staged_instant := false

## Ship.dock_at: what the next enter() docks at, and whether it skips the approach
## (spawning, a Gate transit).
func stage(dockable: Node2D, instant: bool) -> void:
	_staged_dockable = dockable
	_staged_instant = instant

## The staged berth, once: [dockable (or null), instant]. Cleared so the next dock
## starts clean.
func _take_staged() -> Array:
	var staged := [_staged_dockable if Dockable.is_dockable(_staged_dockable) else null, _staged_instant]
	_staged_dockable = null
	_staged_instant = false
	return staged

func _exit_to_flying() -> void:
	var machine := ship.state_machine
	if machine and machine.has_state("FlyingState"):
		machine.change_state("FlyingState")
