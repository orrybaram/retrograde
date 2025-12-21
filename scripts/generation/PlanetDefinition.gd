extends Resource
class_name PlanetDefinition

## Resource defining a single planet in a solar system

@export var planet_name: String = "Planet"
@export var planet_type: Planet.PlanetType = Planet.PlanetType.ROCKY

@export_group("Size & Mass")
@export var radius: float = 300.0
@export var mass_multiplier: float = 25.0

@export_group("Appearance")
@export var color: Color = Color(0.5, 0.5, 0.5)

@export_group("Properties")
@export_range(0.0, 1.0) var habitability: float = 0.0
@export_range(0.0, 1.0) var collision_radius_ratio: float = 1.0

@export_group("Orbital Properties")
## If true, use procedural orbital distance based on orbit index. If false, use explicit orbital_distance.
@export var use_procedural_orbit: bool = true
## Explicit orbital distance (only used if use_procedural_orbit is false)
@export var orbital_distance: float = 100000.0
## Override for orbital speed multiplier (1.0 = standard Kepler speed)
@export var orbital_speed_multiplier: float = 1.0
## Override for eccentricity (0.0 = circular)
@export var eccentricity: float = 0.0
## Initial angle in radians (0.0 = starts at right of sun)
@export var initial_angle: float = 0.0

@export_group("Moons")
## Array of moon definitions orbiting this planet
@export var moons: Array[Resource] = []

