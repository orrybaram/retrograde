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

