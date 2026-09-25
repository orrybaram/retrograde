extends MinimapTarget
class_name SpaceStationMinimapTarget

## MinimapTarget for a SpaceStation: a large echo, and the one shape on the scope that is
## not a smudge - a diamond, so home can always be picked out.

## Roughly a station's reach, world px.
const ECHO_RADIUS := 450.0

var station: SpaceStation

func _init(s: SpaceStation) -> void:
	station = s

func get_minimap_position() -> Vector2:
	if station and is_instance_valid(station):
		return station.global_position
	return Vector2.ZERO

func echo_world_radius() -> float:
	return ECHO_RADIUS

func echo_is_diamond() -> bool:
	return true

func is_minimap_visible() -> bool:
	return station != null and is_instance_valid(station)

func get_minimap_node() -> Node2D:
	return station
