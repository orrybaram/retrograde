extends Node
class_name SolarSystemGenerator

## Procedural solar system generator - Step 1: Sun and player spawn

signal generation_complete(spawn_position: Vector2)

@export var planet_scene: PackedScene = preload("res://entities/Planet/Planet.tscn")

@export_group("Sun Properties")
@export var sun_radius_min: float = 1200.0
@export var sun_radius_max: float = 2000.0
@export var sun_mass_min: float = 500.0
@export var sun_mass_max: float = 1000.0
@export var sun_color_r_min: float = 0.9
@export var sun_color_r_max: float = 1.0
@export var sun_color_g_min: float = 0.7
@export var sun_color_g_max: float = 0.9
@export var sun_color_b_min: float = 0.3
@export var sun_color_b_max: float = 0.6

@export_group("Planet Properties")
@export var planet_count: int = 5
@export var planet_radius_min: float = 150.0
@export var planet_radius_max: float = 800.0
@export var planet_mass_min: float = 10.0
@export var planet_mass_max: float = 100.0
@export var planet_orbital_distance_base: float = 10000.0  ## Base distance for first planet
@export var planet_orbital_distance_multiplier: float = 1.6  ## Multiplier for each subsequent planet
@export var planet_orbital_speed_base: float = 0.005  ## Base orbital speed
@export var planet_eccentricity_max: float = 0.1  ## Maximum orbital eccentricity

@export_group("Ship Spawn")
@export var ship_spawn_distance: float = 5000.0  ## Distance from sun surface to spawn ship

var generated_sun: Planet = null
var generated_planets: Array[Planet] = []
var ship_spawn_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("solar_system_generator")

## Generate the solar system
func generate() -> void:
	print("Generating solar system with seed: ", RNG.seed_value)
	
	# Clear any existing generation
	clear()
	
	# Generate the sun
	generated_sun = _create_sun()
	
	# Generate planets
	for i in range(planet_count):
		var planet = _create_planet(i)
		generated_planets.append(planet)
	
	# Calculate ship spawn position (near the sun)
	ship_spawn_position = Vector2(generated_sun.radius + ship_spawn_distance, 0)
	
	print("Solar system generated!")
	print("  Sun radius: ", generated_sun.radius)
	print("  Planets: ", generated_planets.size())
	print("  Ship spawn: ", ship_spawn_position)
	
	generation_complete.emit(ship_spawn_position)

## Clear generated content
func clear() -> void:
	for planet in generated_planets:
		if planet and is_instance_valid(planet):
			planet.queue_free()
	generated_planets.clear()
	
	if generated_sun and is_instance_valid(generated_sun):
		generated_sun.queue_free()
	generated_sun = null

## Create the central sun
func _create_sun() -> Planet:
	var sun = planet_scene.instantiate() as Planet
	
	# Sun properties - use RNG with exported ranges
	sun.radius = RNG.rng.randf_range(sun_radius_min, sun_radius_max)
	sun.color = Color(
		RNG.rng.randf_range(sun_color_r_min, sun_color_r_max),
		RNG.rng.randf_range(sun_color_g_min, sun_color_g_max),
		RNG.rng.randf_range(sun_color_b_min, sun_color_b_max)
	)
	sun.massMultiplier = RNG.rng.randf_range(sun_mass_min, sun_mass_max)
	sun.enable_orbiting = false
	sun.show_orbit_path = false
	sun.position = Vector2.ZERO
	sun.name = "Sun"
	
	# Add to scene
	get_parent().add_child(sun)
	
	return sun

## Create a planet at the given orbit index
func _create_planet(orbit_index: int) -> Planet:
	var planet = planet_scene.instantiate() as Planet
	
	# Planet properties - use RNG with exported ranges
	planet.radius = RNG.rng.randf_range(planet_radius_min, planet_radius_max)
	
	# Planet colors - Earth-like colors (blues, greens, browns)
	var color_options = [
		Color(0.2, 0.5, 0.8),  # Blue (ocean)
		Color(0.3, 0.6, 0.3),  # Green (forest)
		Color(0.6, 0.4, 0.2),  # Brown (desert)
		Color(0.8, 0.3, 0.2),  # Red (mars-like)
		Color(0.5, 0.5, 0.6),  # Gray (barren)
	]
	var base_color = color_options[RNG.rng.randi() % color_options.size()]
	# Add some variation
	planet.color = Color(
		clamp(base_color.r + RNG.rng.randf_range(-0.1, 0.1), 0.0, 1.0),
		clamp(base_color.g + RNG.rng.randf_range(-0.1, 0.1), 0.0, 1.0),
		clamp(base_color.b + RNG.rng.randf_range(-0.1, 0.1), 0.0, 1.0)
	)
	
	# Mass based on radius
	var mass_range = planet_mass_max - planet_mass_min
	var radius_range = planet_radius_max - planet_radius_min
	var radius_factor = (planet.radius - planet_radius_min) / radius_range if radius_range > 0 else 0.5
	planet.massMultiplier = planet_mass_min + (mass_range * radius_factor)
	
	# Orbital distance - exponentially increasing (Titius-Bode inspired)
	planet.orbital_distance = planet_orbital_distance_base * pow(planet_orbital_distance_multiplier, orbit_index)
	
	# Orbital speed - inversely proportional to distance (Kepler's 3rd law approximation)
	planet.orbital_speed = planet_orbital_speed_base / sqrt(planet.orbital_distance / planet_orbital_distance_base)
	
	# Random initial angle
	planet.initial_angle = RNG.rng.randf_range(0.0, TAU)
	
	# Slight eccentricity
	planet.eccentricity = RNG.rng.randf_range(0.0, planet_eccentricity_max)
	
	# Planet name
	planet.name = "Planet " + str(orbit_index + 1)
	
	# Add as child of sun so it orbits
	generated_sun.add_child(planet)
	
	return planet

## Get spawn position for the ship
func get_ship_spawn_position() -> Vector2:
	return ship_spawn_position

