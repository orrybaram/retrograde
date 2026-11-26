extends TrackingTarget
class_name PointTrackingTarget

## A fixed point in world space, e.g. a player-placed waypoint or a spot
## picked on the system map.

var position: Vector2
var label: String

func _init(world_position: Vector2, target_label: String = "WAYPOINT") -> void:
	position = world_position
	label = target_label

func get_label() -> String:
	return label

func get_position() -> Vector2:
	return position
