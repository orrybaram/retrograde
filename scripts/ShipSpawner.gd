extends Node
class_name ShipSpawner

## Handles ship spawning - finds ShipSpawn locations in the scene

signal spawn_complete()

@onready var ship: Ship = get_node("../Ship")

## Optional override spawn position (for save state)
## If set, this will be used instead of calculating from ShipSpawn locations
var override_spawn_position: Vector2 = Vector2.ZERO
var has_override: bool = false

func _ready() -> void:
	pass

## Main spawn method - finds ShipSpawn location and spawns ship there
func spawn_ship_at_spawn_location() -> void:
	# Wait a frame to ensure everything is initialized
	await get_tree().process_frame
	
	var spawn_position: Vector2
	var spawn_location: ShipSpawn = null
	
	if has_override:
		# Use override position (from save state)
		spawn_position = override_spawn_position
		print("Ship spawning at override position: ", spawn_position)
	else:
		# Find ShipSpawn locations
		var spawn_locations = _find_ship_spawn_locations()
		if not spawn_locations.is_empty():
			spawn_location = _select_best_spawn_location(spawn_locations)
			if spawn_location:
				spawn_position = spawn_location.get_spawn_position()
				var parent = spawn_location.get_parent()
				var parent_name = parent.name if parent else "Unknown"
				print("Ship spawning at ShipSpawn location on ", parent_name, " at: ", spawn_position)
			else:
				spawn_position = _get_fallback_spawn_position()
		else:
			# Fallback spawn position
			spawn_position = _get_fallback_spawn_position()
			print("Ship spawning at fallback position: ", spawn_position)
	
	await spawn_ship(spawn_position, spawn_location)
	spawn_complete.emit()

## Find all ShipSpawn locations in the scene
func _find_ship_spawn_locations() -> Array[ShipSpawn]:
	var spawns: Array[ShipSpawn] = []
	var spawn_nodes = get_tree().get_nodes_in_group("ship_spawns")
	
	for node in spawn_nodes:
		if node is ShipSpawn:
			var spawn = node as ShipSpawn
			if is_instance_valid(spawn):
				spawns.append(spawn)
	
	return spawns

## Select the best spawn location based on priority
## Priority: SpaceStation > SpacePort > Others
func _select_best_spawn_location(spawns: Array[ShipSpawn]) -> ShipSpawn:
	if spawns.is_empty():
		return null
	
	# First priority: SpaceStation with ShipSpawn
	for spawn in spawns:
		var parent = spawn.get_parent()
		if parent is SpaceStation:
			return spawn
	
	# Second priority: SpacePort with ShipSpawn
	for spawn in spawns:
		var parent = spawn.get_parent()
		if parent is SpacePort:
			return spawn
	
	# Fallback: any other ShipSpawn
	return spawns[0]

## Get fallback spawn position if no ShipSpawn locations found
func _get_fallback_spawn_position() -> Vector2:
	# Try to find the Sun and spawn near it
	var sun = get_tree().get_first_node_in_group("planets")
	if sun and sun is Planet:
		var spawn_dist = sun.radius + 5000.0
		return Vector2(spawn_dist, 0)
	
	# Last resort: spawn at origin offset
	return Vector2(20000, 0)

## Spawn ship at the specified position or using a ShipSpawn location
func spawn_ship(spawn_position: Vector2, spawn_location: ShipSpawn = null) -> void:
	if not ship or not is_instance_valid(ship):
		return
	
	# If a ShipSpawn location is provided, use its spawn method
	if spawn_location and is_instance_valid(spawn_location):
		spawn_location.spawn_ship(ship)
		return
	
	# Otherwise use position-based spawning
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
	ship.global_position = spawn_position
	ship.rotation = 0  # Point right
	ship.linear_velocity = Vector2.ZERO
	ship.angular_velocity = 0.0
	
	print("Ship spawned at: ", ship.global_position)

## Public method to spawn at a specific position (for save state)
## Optionally accepts a ShipSpawn location to use its spawn settings
func spawn_at_position(position: Vector2, spawn_location: ShipSpawn = null) -> void:
	override_spawn_position = position
	has_override = true
	await spawn_ship(position, spawn_location)
	spawn_complete.emit()

## Clear override (useful when loading new game)
func clear_override() -> void:
	has_override = false
	override_spawn_position = Vector2.ZERO
