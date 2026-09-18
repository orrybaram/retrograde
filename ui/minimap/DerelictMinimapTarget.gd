extends ResourceMinimapTarget
class_name DerelictMinimapTarget

## MinimapTarget for an abandoned ship: an anonymous contact ring inside a slow mustard
## salvage pulse. Deliberately says nothing about what is out there — finding a hull
## instead of a rock should be the surprise of arriving. Stays on the minimap rim when
## out of range so it can always be found.

func get_minimap_color() -> Color:
	return Colors.HULL_LIGHT

func get_minimap_size() -> float:
	return 4.0

func get_minimap_priority() -> int:
	return 60

func pins_to_edge() -> bool:
	return true

func draw_marker(map: Minimap, pos: Vector2, size: float, _view_rotation: float) -> void:
	var t := fmod(Minimap.now(), 1.6) / 1.6
	map.draw_arc(pos, size * (1.0 + t * 1.2), 0.0, TAU, 20, Color(Colors.PRIMARY, 0.7 * (1.0 - t)), 1.0)
	map.draw_arc(pos, size, 0.0, TAU, 16, get_minimap_color(), 1.4)
