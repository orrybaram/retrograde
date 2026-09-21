extends MinimapTarget
class_name ResourceMinimapTarget

## MinimapTarget for ScrapNode: a small hull-colored chunk that tumbles with the scrap.
## Trophy scrap is a larger mustard chunk that twinkles. Only once a Sweep has found it.

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
	if resource and is_instance_valid(resource) and resource.is_trophy:
		return Colors.PRIMARY
	return Colors.HULL_LIGHT

func get_minimap_size() -> float:
	if resource and is_instance_valid(resource) and resource.is_trophy:
		return 3.0
	return 2.2

func get_minimap_priority() -> int:
	# Resources have low priority (drawn below planets/stations)
	return 10

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

func draw_marker(map: Minimap, pos: Vector2, size: float, view_rotation: float) -> void:
	var color := get_minimap_color()
	if resource.is_trophy:
		color.a = 0.65 + 0.35 * sin(Minimap.now() * 5.0 + pos.x)
	Minimap.draw_fleck(map, pos, size, resource.rotation + view_rotation, color)
