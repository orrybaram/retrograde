extends MinimapTarget
class_name PlanetMinimapTarget

## MinimapTarget for Planet entities: a disc in the planet's color with its night side
## shaded away from the sun, like the planet itself. The sun gets a soft corona.

const MIN_SIZE := 2.5
const NIGHT_SHADE := 0.55  # blend of the night side toward space

var planet: Planet

func _init(p: Planet) -> void:
	planet = p

func get_minimap_position() -> Vector2:
	if planet and is_instance_valid(planet):
		return planet.global_position
	return Vector2.ZERO

func get_minimap_color() -> Color:
	if planet and is_instance_valid(planet):
		return planet.color
	return Colors.PRIMARY

func get_minimap_size() -> float:
	if planet and is_instance_valid(planet):
		# Scale the planet radius to minimap space, then apply the visibility multiplier
		var minimap = Minimap.get_instance(planet.get_tree())
		if minimap:
			var base_size = (planet.radius / minimap.world_range) * minimap.display_radius
			return maxf(base_size * minimap.planet_size_multiplier, MIN_SIZE)
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

func draw_marker(map: Minimap, pos: Vector2, size: float, view_rotation: float) -> void:
	var color := get_minimap_color()
	if planet.planet_type == Planet.PlanetType.SUN:
		for i in 3:
			map.draw_circle(pos, size * (1.25 + 0.3 * i), Color(color, 0.12))
		map.draw_circle(pos, size, color)
		return
	map.draw_circle(pos, size, color)
	if size < 3.0:
		return
	var sun := _find_sun()
	if not sun:
		return
	# Night half: the semicircle facing away from the sun
	var away := (planet.global_position - sun.global_position).angle() + view_rotation
	var points := PackedVector2Array()
	for i in 13:
		points.append(pos + Vector2.from_angle(away - PI / 2 + PI * i / 12.0) * size)
	map.draw_colored_polygon(points, color.lerp(Colors.SPACE_BG, NIGHT_SHADE))

static var _sun: Planet = null

func _find_sun() -> Planet:
	if is_instance_valid(_sun):
		return _sun
	for node in planet.get_tree().get_nodes_in_group("planets"):
		if node is Planet and node.planet_type == Planet.PlanetType.SUN:
			_sun = node
			return _sun
	return null
