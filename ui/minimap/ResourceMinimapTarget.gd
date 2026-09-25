extends MinimapTarget
class_name ResourceMinimapTarget

## MinimapTarget for ScrapNode: the smallest echo on the scope. Only once a Sweep has
## found it.

## A chunk's reach, world px: far under the scope's smallest echo, so all scrap reads the same.
const ECHO_RADIUS := 25.0

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

func echo_world_radius() -> float:
	return ECHO_RADIUS

func is_minimap_visible() -> bool:
	# Only show if resource exists and is not depleted
	if not resource or not is_instance_valid(resource):
		return false
	if resource._is_depleted:
		return false
	# Scrap no Sweep has found yet is just debris, and debris isn't on the map
	return resource.revealed

func get_minimap_node() -> Node2D:
	return resource
