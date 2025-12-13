extends RefCounted
class_name MinimapTarget

## Base interface/abstract class for entities that can be displayed on the minimap.
## Any entity that wants to show on the minimap should extend this class.

## Returns the world position of the target
func get_minimap_position() -> Vector2:
	return Vector2.ZERO

## Returns the color to use for this target on the minimap
func get_minimap_color() -> Color:
	return Color(1.0, 0.75, 0.0)  # Default amber

## Returns the icon type for this target: "dot", "diamond", "triangle", "square"
func get_minimap_icon() -> String:
	return "dot"

## Returns the size of the marker (radius for dots, half-size for others)
func get_minimap_size() -> float:
	return 4.0

## Returns the priority of this target (higher = drawn on top)
func get_minimap_priority() -> int:
	return 0

## Returns whether this target should be visible on the minimap
func is_minimap_visible() -> bool:
	return true

## Returns the Node2D reference for this target
func get_minimap_node() -> Node2D:
	return null

