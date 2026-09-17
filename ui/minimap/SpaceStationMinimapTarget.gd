extends MinimapTarget
class_name SpaceStationMinimapTarget

## MinimapTarget for SpaceStation: the station's own silhouette in hull grey, with a
## blinking blue nav beacon (blue = navigation).

const HEIGHT := 14.0  # marker height in minimap px

var station: SpaceStation
var _outline := PackedVector2Array()  # silhouette scaled to HEIGHT, centred

func _init(s: SpaceStation) -> void:
	station = s
	var shape := s.get_node_or_null("CollisionShape2D") as CollisionPolygon2D
	if shape and shape.polygon.size() >= 3:
		var bounds := Rect2(shape.polygon[0], Vector2.ZERO)
		for p in shape.polygon:
			bounds = bounds.expand(p)
		var k := HEIGHT / maxf(bounds.size.y, 1.0)
		for p in shape.polygon:
			_outline.append((shape.transform * p - bounds.get_center()) * k)

func get_minimap_position() -> Vector2:
	if station and is_instance_valid(station):
		return station.global_position
	return Vector2.ZERO

func get_minimap_color() -> Color:
	return Colors.HULL_LIGHT

func get_minimap_size() -> float:
	return HEIGHT * 0.5

func get_minimap_priority() -> int:
	return 50

func is_minimap_visible() -> bool:
	return station != null and is_instance_valid(station)

func get_minimap_node() -> Node2D:
	return station

func draw_marker(map: Minimap, pos: Vector2, size: float, view_rotation: float) -> void:
	var angle := station.global_rotation + view_rotation
	if _outline.size() >= 3:
		var points := PackedVector2Array()
		for p in _outline:
			points.append(pos + p.rotated(angle))
		map.draw_colored_polygon(points, get_minimap_color())
	else:
		map.draw_rect(Rect2(pos - Vector2(size, size), Vector2(size, size) * 2.0), get_minimap_color())
	var lit := fmod(Minimap.now(), 1.0) < 0.6
	map.draw_circle(pos, 2.0, Colors.NAV if lit else Color(Colors.NAV, 0.35))
