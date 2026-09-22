extends State
class_name ShipState

## Ship-specific base state class that extends the generic State.
## Provides typed access to the Ship entity and ship-specific helpers.

## Typed reference to the Ship entity
var ship: Ship:
	get:
		return entity as Ship

## Helper to check if ship reference is valid
func is_ship_valid() -> bool:
	return ship != null and is_instance_valid(ship)

## Whether holding `action` in this state sends out the sonar resonance (SonarPulse).
## On by default; the states where the ship is tied up or has no power say no.
func allows_sonar() -> bool:
	return true

## Whether clamped Freight stays clamped through this state. Off by default: every other
## state lets go of a load on the way in (see let_go_of_freight).
func holds_freight() -> bool:
	return false

## Leaving a state that held Freight: let go of it, unless the state being entered keeps it.
func let_go_of_freight() -> void:
	if not is_ship_valid() or not ship.is_carrying():
		return
	var next := ship.state_machine.next_state as ShipState if ship.state_machine else null
	if next and next.holds_freight():
		return
	ship.release_freight()
