extends RefCounted
class_name MinimapTarget

## Something the minimap's sonar can find (Minimap). A target says only where it is, how
## big it is, and whether it answers the beam with a ping; the minimap draws every one
## the same way, so size is all that tells them apart.

## The target's world position.
func get_minimap_position() -> Vector2:
	return Vector2.ZERO

## Whether the sonar can find it right now.
func is_minimap_visible() -> bool:
	return true

## The node it stands for (the nav target rings its echo).
func get_minimap_node() -> Node2D:
	return null

## How big the thing is, world px (a radius). The echo is drawn to scale, down to
## Minimap.ECHO_MIN_PX, so most small things come back the same size.
func echo_world_radius() -> float:
	return 0.0

## A planet: comes back as a disc at true scale rather than a smudge.
func is_body() -> bool:
	return false

## Comes back as a diamond rather than a smudge: home, so it can be picked out.
func echo_is_diamond() -> bool:
	return false

## Answers the beam with a ping (a hollow ring) rather than a solid echo.
func is_ping() -> bool:
	return false

## Keep coming back on the rim when out of range, so it can be found.
func pins_to_edge() -> bool:
	return false
