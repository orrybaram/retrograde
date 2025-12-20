extends Resource
class_name SolarSystemData

## Resource defining a complete solar system with predefined planets

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
@export var ship_spawn_distance: float = 5000.0  ## Distance from sun surface to spawn ship

