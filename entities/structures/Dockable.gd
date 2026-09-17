extends Node2D
class_name Dockable

## Base interface for entities that ships can dock to.
## Provides methods for docking position, rotation, distance, and velocity.

## Returns the world position where the ship should dock
func get_dock_position() -> Vector2:
	return global_position

## Returns the rotation of the dockable surface (in radians)
func get_dock_rotation() -> float:
	return global_rotation

## Returns the maximum distance at which docking is allowed
func get_dock_distance() -> float:
	return 30.0  # Default docking range

## Returns the velocity of the dockable entity (for moving platforms)
func get_dock_velocity() -> Vector2:
	# Get velocity from parent if it's a RigidBody2D
	var parent = get_parent()
	if parent is RigidBody2D:
		return (parent as RigidBody2D).linear_velocity
	return Vector2.ZERO

