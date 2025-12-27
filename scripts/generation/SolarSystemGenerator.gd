extends Node
class_name SolarSystemGenerator

## Solar system generator supporting both predefined and procedural generation

signal generation_complete()

enum GenerationMode { PREDEFINED, PROCEDURAL }

@export var planet_scene: PackedScene = preload("res://entities/Planet/Planet.tscn")
@export var space_station_scene: PackedScene = preload("res://entities/structures/SpaceStation.tscn")

@export_group("Generation Mode")
@export var generation_mode: GenerationMode = GenerationMode.PREDEFINED
@export var predefined_system: SolarSystemData = preload("res://scripts/generation/systems/home_system.tres")

## Planet type data resources - loaded from .tres files
@export_group("Planet Type Data")
@export var planet_type_data: Array[PlanetTypeData] = [
	preload("res://entities/Planet/types/sun.tres"),
	preload("res://entities/Planet/types/gas_giant.tres"),
	preload("res://entities/Planet/types/ice_giant.tres"),
	preload("res://entities/Planet/types/earth_like.tres"),
	preload("res://entities/Planet/types/rocky.tres"),
	preload("res://entities/Planet/types/water.tres"),
	preload("res://entities/Planet/types/ice.tres"),
	preload("res://entities/Planet/types/barren.tres")
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
@export var sun_radius_min: float = 5000.0
@export var sun_radius_max: float = 10000.0
@export var sun_mass_min: float = 500.0
@export var sun_mass_max: float = 1000.0
@export var sun_color_r_min: float = 0.9
@export var sun_color_r_max: float = 1.0
@export var sun_color_g_min: float = 0.7
@export var sun_color_g_max: float = 0.9
@export var sun_color_b_min: float = 0.3
@export var sun_color_b_max: float = 0.6
@export var sun_gravitational_constant: float = 8.0  ## Sun's gravitational constant (much stronger than planets)

@export_group("Planet Properties")
@export var planet_count: int = 7
@export var planet_radius_min: float = 1200.0
@export var planet_radius_max: float = 5000.0
@export var planet_mass_min: float = 10.0
@export var planet_mass_max: float = 100.0
@export var planet_orbital_distance_base: float = 100000.0  ## Base distance for first planet
@export var planet_orbital_multiplier_min: float = 1.3  ## Min multiplier for orbital spacing
@export var planet_orbital_multiplier_max: float = 1.8  ## Max multiplier for orbital spacing
@export var planet_orbital_gap_chance: float = 0.15  ## Chance for a large gap (asteroid belt style)
@export var planet_orbital_gap_multiplier: float = 2.1  ## Multiplier for large gaps
@export var planet_orbital_speed_base: float = 0.001  ## Base orbital speed
@export var planet_eccentricity_max: float = 0.1  ## Maximum orbital eccentricity

@export_group("SpaceStation Orbital Parameters")
@export var station_orbital_distance_multiplier: float = 2.5  ## Station orbit distance as multiplier of planet radius
@export var station_orbital_speed_multiplier: float = 1.0  ## Station orbital speed multiplier (relative to planet base speed)
@export var station_use_kepler_law: bool = true  ## If true, calculate speed using Kepler's law. If false, use speed multiplier directly.

var generated_sun: Planet = null
var generated_planets: Array[Planet] = []
var _current_orbital_distance: float = 0.0  # Tracks cumulative orbital distance during generation

func _ready() -> void:
	add_to_group("solar_system_generator")

## Generate the solar system based on current generation mode
func generate() -> void:
	# Clear any existing generation
	clear()
	
	if generation_mode == GenerationMode.PREDEFINED and predefined_system:
		await _generate_from_data(predefined_system)
	else:
		_generate_procedural()
	
	generation_complete.emit()

## Generate solar system from predefined data
func _generate_from_data(system_data: SolarSystemData) -> void:
	print("Generating predefined solar system: ", system_data.system_name)
	
	# Create sun from predefined data
	generated_sun = _create_sun_from_data(system_data)
	
	# Initialize orbital distance tracking (uses same procedural spacing rules)
	_current_orbital_distance = planet_orbital_distance_base
	
	# Create planets from definitions
	for i in range(system_data.planets.size()):
		var planet_def = system_data.planets[i] as PlanetDefinition
		if planet_def:
			var planet = await _create_planet_from_definition(planet_def, i, system_data.planets.size())
			generated_planets.append(planet)
			
			# Spawn SpaceStation orbiting the 6th planet (index 5, Saturn)
			if i == 5:
				await get_tree().process_frame
				_create_space_station_for_planet(planet)
	
	print("Predefined solar system generated!")
	print("  System: ", system_data.system_name)
	print("  Sun radius: ", generated_sun.radius)
	print("  Planets: ", generated_planets.size())

## Generate solar system procedurally
func _generate_procedural() -> void:
	print("Generating procedural solar system with seed: ", RNG.seed_value)
	
	# Generate the sun
	generated_sun = _create_sun()
	
	# Initialize orbital distance tracking
	_current_orbital_distance = planet_orbital_distance_base
	
	# Generate planets
	for i in range(planet_count):
		var planet = _create_planet(i)
		generated_planets.append(planet)
	
	print("Procedural solar system generated!")
	print("  Sun radius: ", generated_sun.radius)
	print("  Planets: ", generated_planets.size())

## Clear generated content
func clear() -> void:
	for planet in generated_planets:
		if planet and is_instance_valid(planet):
			planet.queue_free()
	generated_planets.clear()
	
	if generated_sun and is_instance_valid(generated_sun):
		generated_sun.queue_free()
	generated_sun = null

## Get the current SolarSystemData (for ShipSpawner to access spawn configuration)
func get_current_system_data() -> SolarSystemData:
	if generation_mode == GenerationMode.PREDEFINED:
		return predefined_system
	return null

## Create the central sun
func _create_sun() -> Planet:
	var sun = planet_scene.instantiate() as Planet
	
	# Get sun type data
	var sun_type_data = _get_type_data(Planet.PlanetType.SUN)
	if not sun_type_data:
		push_error("No sun type data found!")
		sun_type_data = planet_type_data[0] if planet_type_data.size() > 0 else null
	
	# Set sun type
	sun.planet_type = Planet.PlanetType.SUN
	
	# Sun properties - use RNG with exported ranges or type data
	if sun_type_data:
		sun.radius = sun_type_data.get_random_radius(RNG.rng)
		sun.color = sun_type_data.get_random_color(RNG.rng)
		sun.massMultiplier = sun_type_data.get_mass_multiplier(sun.radius, RNG.rng)
		sun.collision_radius_ratio = sun_type_data.collision_radius_ratio
		sun.habitability = sun_type_data.habitability
	else:
		# Fallback to old method if no type data
		sun.radius = RNG.rng.randf_range(sun_radius_min, sun_radius_max)
		sun.color = Color(
			RNG.rng.randf_range(sun_color_r_min, sun_color_r_max),
			RNG.rng.randf_range(sun_color_g_min, sun_color_g_max),
			RNG.rng.randf_range(sun_color_b_min, sun_color_b_max)
		)
		sun.massMultiplier = RNG.rng.randf_range(sun_mass_min, sun_mass_max)
	
	# Increase gravitational constant for sun (much stronger gravity)
	sun.gravitational_constant = sun_gravitational_constant
	
	sun.enable_orbiting = false
	sun.show_orbit_path = false
	sun.position = Vector2.ZERO
	sun.name = "Sun"
	
	# Add to scene
	get_parent().add_child(sun)
	
	return sun

## Create the central sun from predefined data
func _create_sun_from_data(system_data: SolarSystemData) -> Planet:
	var sun = planet_scene.instantiate() as Planet
	
	sun.planet_type = Planet.PlanetType.SUN
	sun.radius = system_data.sun_radius
	sun.color = system_data.sun_color
	sun.massMultiplier = system_data.sun_mass_multiplier
	sun.gravitational_constant = system_data.sun_gravitational_constant
	sun.collision_radius_ratio = 1.0
	sun.habitability = 0.0
	
	sun.enable_orbiting = false
	sun.show_orbit_path = false
	sun.position = Vector2.ZERO
	sun.name = "Sun"
	
	get_parent().add_child(sun)
	
	return sun

## Create a planet from a PlanetDefinition resource
func _create_planet_from_definition(planet_def: PlanetDefinition, orbit_index: int, total_planets: int) -> Planet:
	var planet = planet_scene.instantiate() as Planet
	
	# Set properties from definition
	planet.planet_type = planet_def.planet_type
	planet.radius = planet_def.radius
	planet.color = planet_def.color
	planet.collision_radius_ratio = planet_def.collision_radius_ratio
	planet.habitability = planet_def.habitability
	planet.massMultiplier = planet_def.mass_multiplier
	
	# Orbital distance - use procedural spacing or explicit value
	if planet_def.use_procedural_orbit:
		planet.orbital_distance = _current_orbital_distance
		
		# Calculate multiplier for next planet's orbit (same rules as procedural)
		var next_multiplier: float
		var allow_gap = orbit_index >= 2 and orbit_index < total_planets - 2
		if allow_gap and RNG.rng.randf() < planet_orbital_gap_chance:
			next_multiplier = planet_orbital_gap_multiplier * RNG.rng.randf_range(0.9, 1.1)
		else:
			next_multiplier = RNG.rng.randf_range(planet_orbital_multiplier_min, planet_orbital_multiplier_max)
		
		_current_orbital_distance *= next_multiplier
	else:
		planet.orbital_distance = planet_def.orbital_distance
	
	# Orbital speed - inversely proportional to distance (Kepler's 3rd law)
	var base_speed = planet_orbital_speed_base / sqrt(planet.orbital_distance / planet_orbital_distance_base)
	planet.orbital_speed = base_speed * planet_def.orbital_speed_multiplier
	
	# Use defined values for angle and eccentricity
	planet.initial_angle = planet_def.initial_angle
	planet.eccentricity = planet_def.eccentricity
	
	# Planet name from definition
	planet.name = planet_def.planet_name
	
	# Add as child of sun so it orbits
	generated_sun.add_child(planet)
	
	print("  Created: ", planet.name, " - Radius: ", int(planet.radius), ", Habitability: ", "%.1f" % planet.habitability)
	
	# Create moons for this planet after planet is ready
	await get_tree().process_frame
	_create_moons_for_planet(planet, planet_def)
	
	return planet

## Create moons for a planet (called after planet is fully in scene tree)
func _create_moons_for_planet(planet: Planet, planet_def: PlanetDefinition) -> void:
	for moon_def_resource in planet_def.moons:
		var moon_def = moon_def_resource as MoonDefinition
		if moon_def:
			# Create moon but don't add to scene yet
			var moon = _create_moon_from_definition(moon_def, planet)
			# Add moon as child of planet (not sun) - this ensures it orbits the planet
			planet.add_child(moon)
			# Explicitly set parent_planet to ensure it's set correctly
			# This ensures the moon knows to orbit the planet, not the sun
			moon.parent_planet = planet
			moon.orbital_angle = moon.initial_angle
			moon.lock_rotation = true
			# Set initial position based on orbital parameters
			var initial_offset = Vector2(cos(moon.initial_angle), sin(moon.initial_angle)) * moon.orbital_distance
			moon.position = initial_offset
			generated_planets.append(moon)

## Create a moon from a MoonDefinition resource
func _create_moon_from_definition(moon_def: MoonDefinition, parent_planet: Planet) -> Planet:
	var moon = planet_scene.instantiate() as Planet
	
	# Moons are always rocky/barren type
	moon.planet_type = Planet.PlanetType.BARREN
	
	# Calculate moon radius as ratio of parent planet radius
	moon.radius = parent_planet.radius * moon_def.radius_ratio
	
	# Moon appearance
	moon.color = moon_def.color
	moon.collision_radius_ratio = 1.0
	moon.habitability = 0.0
	moon.massMultiplier = moon_def.mass_multiplier
	
	# Orbital distance based on parent planet radius
	moon.orbital_distance = parent_planet.radius * moon_def.orbital_distance_multiplier
	
	# Orbital speed - moons orbit faster than planets
	# Base speed calculation similar to planets but scaled for closer orbits
	var moon_base_speed = planet_orbital_speed_base * moon_def.orbital_speed_multiplier
	# Moons are much closer, so they need faster angular velocity
	moon.orbital_speed = moon_base_speed * (planet_orbital_distance_base / moon.orbital_distance)
	
	# Orbital properties
	moon.initial_angle = moon_def.initial_angle
	moon.eccentricity = moon_def.eccentricity
	moon.enable_orbiting = true
	moon.show_orbit_path = true
	
	# Moon name
	moon.name = moon_def.moon_name
	
	# Note: Moon will be added as child of parent planet by caller
	# This ensures proper scene tree hierarchy
	
	print("    Created moon: ", moon.name, " - Radius: ", int(moon.radius), " (orbiting ", parent_planet.name, ")")
	
	return moon

## Create a planet at the given orbit index (procedural)
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
	
	# Add as child of sun so it orbits
	generated_sun.add_child(planet)
	
	return planet

## Create a SpaceStation that orbits a planet
func _create_space_station_for_planet(planet: Planet) -> void:
	if not space_station_scene:
		push_error("SpaceStation scene not set in SolarSystemGenerator")
		return
	
	var station = space_station_scene.instantiate() as SpaceStation
	if not station:
		push_error("Failed to instantiate SpaceStation")
		return
	
	# Set orbital parameters for the station
	# Orbit at a distance from the planet (outside its radius)
	var planet_radius = planet.radius
	station.orbital_distance = planet_radius * station_orbital_distance_multiplier
	
	# Calculate orbital speed
	if station_use_kepler_law:
		# Use Kepler's 3rd law approximation (speed inversely proportional to sqrt of distance)
		var base_speed = planet_orbital_speed_base * station_orbital_speed_multiplier
		station.orbital_speed = base_speed / sqrt(station.orbital_distance / planet_orbital_distance_base)
	else:
		# Use direct speed multiplier
		station.orbital_speed = planet_orbital_speed_base * station_orbital_speed_multiplier
	
	# Random initial angle
	station.initial_angle = RNG.rng.randf_range(0.0, TAU)
	station.eccentricity = 0.0  # Circular orbit
	
	# Set initial position based on orbital parameters
	var initial_offset = Vector2(cos(station.initial_angle), sin(station.initial_angle)) * station.orbital_distance
	station.position = initial_offset
	
	# Add as child of planet so it orbits the planet
	planet.add_child(station)
	
	# Explicitly set parent_planet to ensure orbital mechanics work
	station.parent_planet = planet
	station.orbital_angle = station.initial_angle
	station.lock_rotation = true
	
	print("  Created SpaceStation orbiting: ", planet.name, " at distance: ", int(station.orbital_distance))

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
