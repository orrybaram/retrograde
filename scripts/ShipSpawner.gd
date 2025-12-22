extends Node
class_name ShipSpawner

## Handles ship spawning independently from solar system generation
## Supports save state override and default spawn configuration from SolarSystemData

signal spawn_complete()

@onready var ship: Ship = get_node("../Ship")
@onready var generator: SolarSystemGenerator = get_node("../SolarSystemGenerator")

## Optional override spawn position (for save state)
## If set, this will be used instead of calculating from SolarSystemData
var override_spawn_position: Vector2 = Vector2.ZERO
var has_override: bool = false

func _ready() -> void:
	# Connect to generation complete signal
	if generator:
		generator.generation_complete.connect(_on_generation_complete)

## Called when solar system generation completes
func _on_generation_complete() -> void:
	# Wait a frame to ensure everything is initialized
	await get_tree().process_frame
	
	var spawn_position: Vector2
	
	if has_override:
		# Use override position (from save state)
		spawn_position = override_spawn_position
		print("Ship spawning at override position: ", spawn_position)
	else:
		# Calculate spawn position from SolarSystemData
		spawn_position = _calculate_spawn_position()
		print("Ship spawning at calculated position: ", spawn_position)
	
	await spawn_ship(spawn_position)
	spawn_complete.emit()

## Calculate spawn position from SolarSystemData
func _calculate_spawn_position() -> Vector2:
	var system_data = generator.get_current_system_data()
	
	if not system_data:
		# Fallback: spawn near sun for procedural generation
		if generator.generated_sun:
			var spawn_dist = generator.generated_sun.radius + 5000.0
			return Vector2(spawn_dist, 0)
		return Vector2.ZERO
	
	match system_data.spawn_mode:
		SolarSystemData.SpawnMode.AT_POSITION:
			# Use explicit position from system data
			return system_data.spawn_position
		
		SolarSystemData.SpawnMode.NEAR_SUN:
			# Spawn near the sun
			if not generator.generated_sun:
				return Vector2.ZERO
			var spawn_dist = generator.generated_sun.radius + system_data.ship_spawn_distance
			return Vector2(spawn_dist, 0)
		
		SolarSystemData.SpawnMode.NEAR_PLANET, _:
			# Spawn near a specific planet
			var target_planet: Planet = null
			for planet in generator.generated_planets:
				if planet and is_instance_valid(planet) and planet.name == system_data.spawn_planet_name:
					target_planet = planet
					break
			
			if target_planet:
				# Spawn just outside the planet's orbit, at the same angle as the planet
				var spawn_dist = target_planet.orbital_distance + system_data.ship_spawn_distance
				var spawn_angle = target_planet.initial_angle
				return Vector2(cos(spawn_angle), sin(spawn_angle)) * spawn_dist
			else:
				# Fallback: spawn near the sun if target planet not found
				push_warning("Spawn planet '%s' not found. Spawning near sun." % system_data.spawn_planet_name)
				if generator.generated_sun:
					var spawn_dist = generator.generated_sun.radius + system_data.ship_spawn_distance
					return Vector2(spawn_dist, 0)
				return Vector2.ZERO

## Spawn ship at the specified position
func spawn_ship(spawn_position: Vector2) -> void:
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
	ship.global_position = spawn_position
	ship.rotation = 0  # Point right
	ship.linear_velocity = Vector2.ZERO
	ship.angular_velocity = 0.0
	
	print("Ship spawned at: ", ship.global_position)

## Public method to spawn at a specific position (for save state)
func spawn_at_position(position: Vector2) -> void:
	override_spawn_position = position
	has_override = true
	await spawn_ship(position)
	spawn_complete.emit()

## Public method to spawn using system data (default behavior)
func spawn_from_system_data() -> void:
	has_override = false
	var spawn_position = _calculate_spawn_position()
	await spawn_ship(spawn_position)
	spawn_complete.emit()

## Clear override (useful when loading new game)
func clear_override() -> void:
	has_override = false
	override_spawn_position = Vector2.ZERO
