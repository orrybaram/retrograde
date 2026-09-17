extends MinimapTarget
class_name LandingSiteMinimapTarget

## MinimapTarget for a revealed LandingSite: a small mustard pad bracket facing out of
## the planet, with a blinking beacon dot. Spent sites are dim and steady.

var site: LandingSite

func _init(s: LandingSite) -> void:
	site = s

func get_minimap_position() -> Vector2:
	return site.global_position if is_instance_valid(site) else Vector2.ZERO

func get_minimap_color() -> Color:
	return site.beacon_color() if is_instance_valid(site) else Colors.PRIMARY

func get_minimap_size() -> float:
	return 3.0

func get_minimap_priority() -> int:
	# Above planets (radius / 10) so the pad is drawn over its planet's disc
	return 5000

func is_minimap_visible() -> bool:
	return is_instance_valid(site) and site.is_revealed()

func get_minimap_node() -> Node2D:
	return site

func draw_marker(map: Minimap, pos: Vector2, size: float, view_rotation: float) -> void:
	var color := get_minimap_color()
	var out := Vector2.from_angle(site.global_rotation + view_rotation)
	var side := out.orthogonal() * size
	var lip := out * size * 0.8
	map.draw_polyline(PackedVector2Array([pos - side + lip, pos - side, pos + side, pos + side + lip]), color, 1.5)
	var lit := site.is_spent() or fmod(Minimap.now(), LandingSite.BLINK_PERIOD) < LandingSite.BLINK_PERIOD * 0.55
	map.draw_circle(pos + out * size * 1.6, 1.3, color if lit else Color(color, 0.35))
