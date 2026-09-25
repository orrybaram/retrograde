extends MinimapTarget
class_name PlanetMinimapTarget

## MinimapTarget for a Planet (or the Sun): a disc at true scale. The biggest thing on the
## scope, and still just an echo.

var planet: Planet

func _init(p: Planet) -> void:
	planet = p

func get_minimap_position() -> Vector2:
	if planet and is_instance_valid(planet):
		return planet.global_position
	return Vector2.ZERO

func echo_world_radius() -> float:
	return planet.radius if planet and is_instance_valid(planet) else 0.0

func is_body() -> bool:
	return true

func is_minimap_visible() -> bool:
	return planet != null and is_instance_valid(planet)

func get_minimap_node() -> Node2D:
	return planet
