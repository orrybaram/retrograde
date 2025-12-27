extends MinimapTarget
class_name ResourceMinimapTarget

## MinimapTarget implementation for ResourceNode entities.

var resource: ResourceNode

func _init(r: ResourceNode) -> void:
	resource = r

func get_minimap_position() -> Vector2:
	if resource and is_instance_valid(resource):
		return resource.global_position
	return Vector2.ZERO

func get_minimap_color() -> Color:
	# Use a distinct color for resources (green/yellow)
	if resource and is_instance_valid(resource):
		# Use the resource's color (ResourceNode has a color property)
		return resource.color
	return Color(0.4, 0.9, 0.4)  # Fallback light green

func get_minimap_icon() -> String:
	return "dot"  # Small dot for resources

func get_minimap_size() -> float:
	# Small size for resources
	return 1.0

func get_minimap_priority() -> int:
	# Resources have low priority (drawn below planets/stations)
	return 10

func is_minimap_visible() -> bool:
	# Only show if resource exists and is not depleted
	if not resource or not is_instance_valid(resource):
		return false
	# Check if resource is depleted (ResourceNode has _is_depleted property)
	if resource._is_depleted:
		return false
	return true

func get_minimap_node() -> Node2D:
	return resource
