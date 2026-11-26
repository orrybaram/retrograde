extends TrackingTarget
class_name NodeTrackingTarget

## Tracks a live Node2D (station, planet, ship...). Velocity comes from the
## node's physics body when it has one.

var node: Node2D
var label: String
var arrival_radius: float

func _init(target_node: Node2D, target_label: String = "", radius: float = 80.0) -> void:
	node = target_node
	label = target_label if target_label != "" else (str(target_node.name) if target_node else "")
	arrival_radius = radius

func get_label() -> String:
	return label

func get_position() -> Vector2:
	return node.global_position if is_valid() else Vector2.ZERO

func get_velocity() -> Vector2:
	if not is_valid():
		return Vector2.ZERO
	if node is RigidBody2D:
		return (node as RigidBody2D).linear_velocity
	if node is CharacterBody2D:
		return (node as CharacterBody2D).velocity
	return Vector2.ZERO

func is_valid() -> bool:
	return node != null and is_instance_valid(node) and node.is_inside_tree()

func get_arrival_radius() -> float:
	return arrival_radius
