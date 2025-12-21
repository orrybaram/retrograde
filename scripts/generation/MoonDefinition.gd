extends Resource
class_name MoonDefinition

## Resource defining a single moon orbiting a planet

@export var moon_name: String = "Moon"

@export_group("Size & Mass")
## Radius as a ratio of parent planet radius (0.2 = 20%, 0.4 = 40%)
@export_range(0.1, 0.5) var radius_ratio: float = 0.3
@export var mass_multiplier: float = 5.0

@export_group("Appearance")
@export var color: Color = Color(0.5, 0.5, 0.5)

@export_group("Orbital Properties")
## Orbital distance as a multiplier of parent planet radius (e.g., 3.0 = 3x parent radius)
@export var orbital_distance_multiplier: float = 3.0
## Orbital speed multiplier (higher = faster orbit, moons typically orbit faster than planets)
@export var orbital_speed_multiplier: float = 1.0
## Eccentricity (0.0 = circular)
@export_range(0.0, 0.1) var eccentricity: float = 0.0
## Initial angle in radians (0.0 = starts at right of planet)
@export var initial_angle: float = 0.0
