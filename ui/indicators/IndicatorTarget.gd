extends RefCounted
class_name IndicatorTarget

## Base interface/abstract class for entities that can display indicators.
## Any entity that wants to show an indicator should extend this class.

## Returns the priority of this indicator (higher = shown first when multiple are available)
func get_indicator_priority() -> int:
	return 0

## Returns the world position of the target
func get_indicator_position() -> Vector2:
	return Vector2.ZERO

## Returns the bounds of the target for drawing the bracket
func get_indicator_bounds() -> Rect2:
	return Rect2()

## Returns a dictionary with information to display in the info box
## Expected keys: "title", "subtitle", "details" (array of strings)
func get_indicator_info() -> Dictionary:
	return {}

## Returns whether this indicator should be visible
func is_indicator_visible() -> bool:
	return true

## Returns the Node2D reference for world-to-screen conversion
func get_indicator_node() -> Node2D:
	return null
