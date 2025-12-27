extends Node
class_name ShipSpawn

## ShipSpawn component that can be attached to any entity.
## Provides spawn position and handles ship spawning functionality.

@export var spawn_offset: Vector2 = Vector2(0, -50)
## Position offset relative to parent entity (default: spawn above landing pad)

@export var spawn_rotation: float = 0.0
## Initial rotation for spawned ships (in radians)

@export var spawn_velocity: Vector2 = Vector2.ZERO
## Initial velocity for spawned ships

func _ready() -> void:
	add_to_group("ship_spawns")

## Get the world position of the spawn point
func get_spawn_position() -> Vector2:
	var parent = get_parent()
	if parent and parent is Node2D:
		var parent_node = parent as Node2D
		return parent_node.global_position + spawn_offset
	return Vector2.ZERO

## Spawn a ship at this spawn point
func spawn_ship(ship: Ship) -> void:
	if not ship or not is_instance_valid(ship):
		return
	
	var spawn_position = get_spawn_position()
	spawn_ship_at_position(ship, spawn_position)

## Spawn a ship at a specific world position
func spawn_ship_at_position(ship: Ship, position: Vector2) -> void:
	if not ship or not is_instance_valid(ship):
		return
	
	# Wait for a frame to ensure everything is initialized
	await get_tree().process_frame
	
	# Temporarily unpause for physics if needed
	var was_paused = get_tree().paused
	if was_paused:
		get_tree().paused = false
		await get_tree().physics_frame
		get_tree().paused = true
	
	if not is_instance_valid(ship):
		return
	
	# Position ship at spawn location
	ship.global_position = position
	ship.rotation = spawn_rotation
	ship.linear_velocity = spawn_velocity
	ship.angular_velocity = 0.0
	
	print("Ship spawned at: ", ship.global_position)

