extends MinimapTarget
class_name SpaceStationMinimapTarget

## MinimapTarget implementation for SpaceStation entities.

var station: SpaceStation

func _init(s: SpaceStation) -> void:
	station = s

func get_minimap_position() -> Vector2:
	if station and is_instance_valid(station):
		return station.global_position
	return Vector2.ZERO

func get_minimap_color() -> Color:
	# Use a distinct color for space stations (cyan/blue)
	return Color(0.2, 0.8, 1.0)  # Cyan-blue

func get_minimap_icon() -> String:
	return "square"  # Use square to distinguish from planets

func get_minimap_size() -> float:
	# Fixed size for space stations
	return 6.0

func get_minimap_priority() -> int:
	# Space stations have medium priority
	return 50

func is_minimap_visible() -> bool:
	return station != null and is_instance_valid(station)

func get_minimap_node() -> Node2D:
	return station

