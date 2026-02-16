extends MinimapTarget
class_name ResourceMinimapTarget

## MinimapTarget implementation for ScrapNode entities.

var resource: ScrapNode

func _init(r: ScrapNode) -> void:
	resource = r

func get_minimap_position() -> Vector2:
	if not resource or not is_instance_valid(resource):
		return Vector2.ZERO

	# Use OrbitalMotion's predicted position to avoid stale global_position
	# (distant/sleeping nodes don't update their position every frame)
	var orbital = resource._orbital_motion
	if orbital and orbital.initialized:
		var pos = orbital.get_predicted_global_position()
		if pos != Vector2.ZERO:
			return pos

	return resource.global_position

func get_minimap_color() -> Color:
	# Use a distinct color for resources (green/yellow)
	if resource and is_instance_valid(resource):
		# Use the resource's color (ScrapNode has a color property)
		return resource.color
	return Color(0.4, 0.9, 0.4)  # Fallback light green

func get_minimap_icon() -> String:
	return "dot"  # Small dot for resources

func get_minimap_size() -> float:
	return 2.0

func get_minimap_priority() -> int:
	# Resources have low priority (drawn below planets/stations)
	return 10

func is_minimap_visible() -> bool:
	# Only show if resource exists and is not depleted
	if not resource or not is_instance_valid(resource):
		return false
	if resource._is_depleted:
		return false
	return true

func get_minimap_node() -> Node2D:
	return resource
