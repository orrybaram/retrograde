extends Node
class_name SolarSystemGenerator

## Procedural solar system generator with planet types

signal generation_complete(spawn_position: Vector2)

@export var planet_scene: PackedScene = preload("res://entities/Planet/Planet.tscn")

## Planet type data resources - loaded from .tres files
@export_group("Planet Type Data")
@export var planet_type_data: Array[PlanetTypeData] = [
	preload("res://resources/planet_types/gas_giant.tres"),
	preload("res://resources/planet_types/ice_giant.tres"),
	preload("res://resources/planet_types/earth_like.tres"),
	preload("res://resources/planet_types/rocky.tres"),
	preload("res://resources/planet_types/water.tres"),
	preload("res://resources/planet_types/ice.tres"),
	preload("res://resources/planet_types/barren.tres")
]

## Get planet type data by type enum
func _get_type_data(planet_type: Planet.PlanetType) -> PlanetTypeData:
	for data in planet_type_data:
		if data.planet_type == planet_type:
			return data
	# Fallback to rocky if not found
	return planet_type_data[3] if planet_type_data.size() > 3 else null

## Planet type weights by orbit zone (inner, middle, outer)
const INNER_PLANET_WEIGHTS = {
	Planet.PlanetType.ROCKY: 40,
	Planet.PlanetType.BARREN: 30,
	Planet.PlanetType.EARTH_LIKE: 20,
	Planet.PlanetType.WATER: 10
}

const MIDDLE_PLANET_WEIGHTS = {
	Planet.PlanetType.EARTH_LIKE: 30,
	Planet.PlanetType.WATER: 25,
	Planet.PlanetType.ROCKY: 20,
	Planet.PlanetType.ICE: 15,
	Planet.PlanetType.BARREN: 10
}

const OUTER_PLANET_WEIGHTS = {
	Planet.PlanetType.GAS_GIANT: 35,
	Planet.PlanetType.ICE_GIANT: 30,
	Planet.PlanetType.ICE: 20,
	Planet.PlanetType.BARREN: 15
}

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
@export var planet_count: int = 7
@export var planet_radius_min: float = 150.0
@export var planet_radius_max: float = 800.0
@export var planet_mass_min: float = 10.0
@export var planet_mass_max: float = 100.0
@export var planet_orbital_distance_base: float = 100000.0  ## Base distance for first planet
@export var planet_orbital_multiplier_min: float = 1.3  ## Min multiplier for orbital spacing
@export var planet_orbital_multiplier_max: float = 1.8  ## Max multiplier for orbital spacing
@export var planet_orbital_gap_chance: float = 0.15  ## Chance for a large gap (asteroid belt style)
@export var planet_orbital_gap_multiplier: float = 2.1  ## Multiplier for large gaps
@export var planet_orbital_speed_base: float = 0.005  ## Base orbital speed
@export var planet_eccentricity_max: float = 0.1  ## Maximum orbital eccentricity

@export_group("Ship Spawn")
@export var ship_spawn_distance: float = 5000.0  ## Distance from sun surface to spawn ship

var generated_sun: Planet = null
var generated_planets: Array[Planet] = []
var ship_spawn_position: Vector2 = Vector2.ZERO
var _current_orbital_distance: float = 0.0  # Tracks cumulative orbital distance during generation

func _ready() -> void:
	add_to_group("solar_system_generator")

## Generate the solar system
func generate() -> void:
	print("Generating solar system with seed: ", RNG.seed_value)
	
	# Clear any existing generation
	clear()
	
	# Generate the sun
	generated_sun = _create_sun()
	
	# Initialize orbital distance tracking
	_current_orbital_distance = planet_orbital_distance_base
	
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
	
	# Select planet type based on orbital position
	var selected_type = _select_planet_type(orbit_index)
	var type_data = _get_type_data(selected_type)
	
	if not type_data:
		push_error("No type data found for planet type: ", selected_type)
		return planet
	
	# Set planet type
	planet.planet_type = selected_type
	
	# Set radius from type-specific range (using resource method)
	planet.radius = type_data.get_random_radius(RNG.rng)
	
	# Set color from type palette (using resource method)
	planet.color = type_data.get_random_color(RNG.rng)
	
	# Set collision ratio (gas giants have smaller cores)
	planet.collision_radius_ratio = type_data.collision_radius_ratio
	
	# Set habitability with slight random variation (using resource method)
	planet.habitability = type_data.get_habitability_varied(RNG.rng)
	
	# Mass based on type and radius (using resource method)
	planet.massMultiplier = type_data.get_mass_multiplier(planet.radius, RNG.rng)
	
	# Orbital distance - use cumulative distance with variable spacing
	planet.orbital_distance = _current_orbital_distance
	
	# Calculate multiplier for next planet's orbit
	# Only allow gaps in the middle planets (not first 2 or last 2)
	var next_multiplier: float
	var allow_gap = orbit_index >= 2 and orbit_index < planet_count - 2
	if allow_gap and RNG.rng.randf() < planet_orbital_gap_chance:
		# Large gap (like asteroid belt)
		next_multiplier = planet_orbital_gap_multiplier * RNG.rng.randf_range(0.9, 1.1)
	else:
		# Normal spacing with variance
		next_multiplier = RNG.rng.randf_range(planet_orbital_multiplier_min, planet_orbital_multiplier_max)
	
	# Update cumulative distance for next planet
	_current_orbital_distance *= next_multiplier
	
	# Orbital speed - inversely proportional to distance (Kepler's 3rd law approximation)
	planet.orbital_speed = planet_orbital_speed_base / sqrt(planet.orbital_distance / planet_orbital_distance_base)
	
	# Random initial angle
	planet.initial_angle = RNG.rng.randf_range(0.0, TAU)
	
	# Slight eccentricity
	planet.eccentricity = RNG.rng.randf_range(0.0, planet_eccentricity_max)
	
	# Planet name includes type (from resource)
	planet.name = "Planet %d (%s)" % [orbit_index + 1, type_data.type_name]
	
	# Add as child of sun so it orbits
	generated_sun.add_child(planet)
	
	print("  Created: ", planet.name, " - Radius: ", int(planet.radius), ", Habitability: ", "%.1f" % planet.habitability)
	
	return planet

## Get spawn position for the ship
func get_ship_spawn_position() -> Vector2:
	return ship_spawn_position

## Select a planet type based on weighted random selection
func _select_planet_type(orbit_index: int) -> Planet.PlanetType:
	var weights: Dictionary
	
	# Determine which zone this orbit is in
	var orbit_fraction = float(orbit_index) / float(max(planet_count - 1, 1))
	
	if orbit_fraction < 0.33:
		weights = INNER_PLANET_WEIGHTS
	elif orbit_fraction < 0.66:
		weights = MIDDLE_PLANET_WEIGHTS
	else:
		weights = OUTER_PLANET_WEIGHTS
	
	# Calculate total weight
	var total_weight = 0
	for weight in weights.values():
		total_weight += weight
	
	# Random selection
	var roll = RNG.rng.randi() % total_weight
	var cumulative = 0
	
	for planet_type in weights:
		cumulative += weights[planet_type]
		if roll < cumulative:
			return planet_type
	
	# Fallback
	return Planet.PlanetType.ROCKY
