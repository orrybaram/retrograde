extends MinimapTarget
class_name OreMinimapTarget

## MinimapTarget for a revealed OreDeposit: a small hexagon on its planet's rim,
## breathing slowly. Spent seams are dim and still.

const SIZE := 3.2

var ore: OreDeposit

func _init(deposit: OreDeposit) -> void:
	ore = deposit

func get_minimap_position() -> Vector2:
	return ore.global_position if is_instance_valid(ore) else Vector2.ZERO

func get_minimap_color() -> Color:
	return ore.ore_color() if is_instance_valid(ore) else Colors.PRIMARY

func get_minimap_size() -> float:
	return SIZE

func get_minimap_priority() -> int:
	# Above planets (radius / 10) so a seam is drawn over its planet's disc
	return 5000

func is_minimap_visible() -> bool:
	return is_instance_valid(ore) and ore.is_revealed()

func get_minimap_node() -> Node2D:
	return ore

func draw_marker(map: Minimap, pos: Vector2, size: float, _view_rotation: float) -> void:
	var color := get_minimap_color()
	var breathe := 1.0 if ore.is_spent() else 1.0 + 0.15 * sin(Minimap.now() * OreDeposit.SHIMMER_SPEED)
	var points := OreDeposit.hex_points(pos, size * breathe)
	map.draw_colored_polygon(points, Color(color, 0.3))
	points.append(points[0])
	map.draw_polyline(points, color, 1.2)
