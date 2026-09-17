extends RefCounted
class_name MinimapTarget

## Base interface/abstract class for entities that can be displayed on the minimap.
## Any entity that wants to show on the minimap should extend this class.

## Returns the world position of the target
func get_minimap_position() -> Vector2:
	return Vector2.ZERO

## Returns the color to use for this target on the minimap
func get_minimap_color() -> Color:
	return Colors.PRIMARY

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

## Keep drawing at the minimap rim when out of range (for things you need to find).
func pins_to_edge() -> bool:
	return false

## Draw the marker centred on `pos`. `size` is get_minimap_size(); `view_rotation` is
## added to world headings (non-zero when the minimap rotates with the ship).
## Default: the simple icon from get_minimap_icon().
func draw_marker(map: Minimap, pos: Vector2, size: float, view_rotation: float) -> void:
	var color := get_minimap_color()
	match get_minimap_icon():
		"diamond":
			Minimap.draw_diamond(map, pos, size, color)
		"triangle":
			Minimap.draw_chevron(map, pos, size, -PI / 2 + view_rotation, color)
		"square":
			map.draw_rect(Rect2(pos - Vector2(size, size), Vector2(size, size) * 2.0), color)
		_:
			map.draw_circle(pos, size, color)

