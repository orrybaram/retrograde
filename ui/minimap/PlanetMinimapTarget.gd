extends MinimapTarget
class_name PlanetMinimapTarget

## MinimapTarget implementation for Planet entities.

var planet: Planet

func _init(p: Planet) -> void:
	planet = p

func get_minimap_position() -> Vector2:
	if planet and is_instance_valid(planet):
		return planet.global_position
	return Vector2.ZERO

func get_minimap_color() -> Color:
	if planet and is_instance_valid(planet):
		# Use the planet's color, slightly adjusted for visibility
		return planet.color
	return Color(1.0, 0.75, 0.0)  # Fallback amber

func get_minimap_icon() -> String:
	return "dot"

func get_minimap_size() -> float:
	if planet and is_instance_valid(planet):
		# Scale the marker size based on actual planet radius
		# Scale to minimap coordinates (world_range maps to display_radius)
		# Get minimap reference to access world_range and planet_size_multiplier
		var minimap = Minimap.get_instance(planet.get_tree())
		if minimap:
			# Scale planet radius to minimap space, then apply multiplier for visibility
			var base_size = (planet.radius / minimap.world_range) * minimap.display_radius
			return base_size * minimap.planet_size_multiplier
		# Fallback: scale by fixed ratio
		return planet.radius / 100.0
	return 4.0

func get_minimap_priority() -> int:
	# Larger planets have higher priority (drawn on top)
	if planet and is_instance_valid(planet):
		return int(planet.radius / 10.0)
	return 0

func is_minimap_visible() -> bool:
	return planet != null and is_instance_valid(planet)

func get_minimap_node() -> Node2D:
	return planet

