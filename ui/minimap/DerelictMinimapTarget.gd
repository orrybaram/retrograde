extends ResourceMinimapTarget
class_name DerelictMinimapTarget

## MinimapTarget for an abandoned ship: a powered-down copy of the player's arrowhead,
## turned the way the hull is facing, inside a slow mustard salvage pulse. Stays on the
## minimap rim when out of range so it can always be found.

func get_minimap_color() -> Color:
	return Colors.HULL_LIGHT

func get_minimap_size() -> float:
	return 5.5

func get_minimap_priority() -> int:
	return 60

func pins_to_edge() -> bool:
	return true

func draw_marker(map: Minimap, pos: Vector2, size: float, view_rotation: float) -> void:
	var t := fmod(Minimap.now(), 1.6) / 1.6
	map.draw_arc(pos, size * (1.0 + t * 1.2), 0.0, TAU, 20, Color(Colors.PRIMARY, 0.7 * (1.0 - t)), 1.0)
	Minimap.draw_chevron(map, pos, size, resource.rotation + view_rotation, get_minimap_color())
