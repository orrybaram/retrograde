extends RefCounted
class_name TrackingTarget

## Something the player (or any other entity) can navigate toward.
## Subclass this for each kind of trackable thing: world nodes, fixed
## waypoints, map selections. A Tracker holds at most one at a time.

## Short name shown on the HUD, e.g. "HOME".
func get_label() -> String:
	return ""

## World position to steer toward.
func get_position() -> Vector2:
	return Vector2.ZERO

## World velocity of the target, used for relative speed.
func get_velocity() -> Vector2:
	return Vector2.ZERO

## False once the target no longer exists; trackers drop invalid targets.
func is_valid() -> bool:
	return true

## Distance (world units) at which the target counts as reached.
func get_arrival_radius() -> float:
	return 80.0
