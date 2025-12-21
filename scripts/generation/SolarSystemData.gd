extends Resource
class_name SolarSystemData

## Resource defining a complete solar system with predefined planets

enum SpawnMode { NEAR_PLANET, NEAR_SUN, AT_POSITION }

@export var system_name: String = "Unknown System"

@export_group("Sun Properties")
@export var sun_radius: float = 1500.0
@export var sun_color: Color = Color(1.0, 0.9, 0.5)
@export var sun_mass_multiplier: float = 800.0
@export var sun_gravitational_constant: float = 8.0

@export_group("Planets")
## Array of planet definitions, ordered from innermost to outermost orbit
@export var planets: Array[Resource] = []

@export_group("Ship Spawn")
@export var spawn_mode: SpawnMode = SpawnMode.NEAR_PLANET
## Name of the planet to spawn near (only used if spawn_mode is NEAR_PLANET)
@export var spawn_planet_name: String = "Earth"
## Explicit spawn position (only used if spawn_mode is AT_POSITION)
@export var spawn_position: Vector2 = Vector2.ZERO
## Distance offset from planet surface or sun surface
@export var ship_spawn_distance: float = 5000.0

