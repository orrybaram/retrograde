extends MinimapTarget
class_name OreMinimapTarget

## MinimapTarget for a revealed OreDeposit: a small chunk of rock on its planet's rim.
## It shrinks as the seam is drilled out and leaves the map entirely once the seam is
## spent, coming back when the seam refills. Mustard, like every other instrument mark.

const SIZE := 3.4
const MIN_SIZE := 1.6
static var MARKER_JAG := PackedFloat32Array([1.18, 0.86, 1.1, 0.8, 1.14, 0.9, 1.0])

var ore: OreDeposit

func _init(deposit: OreDeposit) -> void:
	ore = deposit

func get_minimap_position() -> Vector2:
	return ore.global_position if is_instance_valid(ore) else Vector2.ZERO

func get_minimap_color() -> Color:
	return Colors.PRIMARY

func get_minimap_size() -> float:
	return lerpf(MIN_SIZE, SIZE, ore.remaining()) if is_instance_valid(ore) else SIZE

func get_minimap_priority() -> int:
	# Above planets (radius / 10) so a seam is drawn over its planet's disc
	return 5000

func is_minimap_visible() -> bool:
	return is_instance_valid(ore) and ore.is_revealed() and not ore.is_spent()

func get_minimap_node() -> Node2D:
	return ore

func draw_marker(map: Minimap, pos: Vector2, size: float, _view_rotation: float) -> void:
	var color := get_minimap_color()
	var points := OreDeposit.rock_points(pos, size, 0.0, MARKER_JAG)
	map.draw_colored_polygon(points, Color(color, 0.3))
	points.append(points[0])
	map.draw_polyline(points, color, 1.2)
