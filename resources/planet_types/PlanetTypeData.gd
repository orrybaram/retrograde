extends Resource
class_name PlanetTypeData

## Resource defining properties for a planet type

@export var type_name: String = "Unknown"
@export var planet_type: Planet.PlanetType = Planet.PlanetType.ROCKY

@export_group("Size")
@export var radius_min: float = 150.0
@export var radius_max: float = 300.0

@export_group("Physics")
@export var collision_radius_ratio: float = 1.0  ## 1.0 = full, 0.3 = small core (gas giants)
@export var mass_multiplier_base: float = 20.0

@export_group("Habitability")
@export_range(0.0, 1.0) var habitability: float = 0.0

@export_group("Appearance")
@export var color_palette: Array[Color] = []

## Get a random color from the palette with slight variation
func get_random_color(rng: RandomNumberGenerator) -> Color:
	if color_palette.is_empty():
		return Color.WHITE
	
	var base_color = color_palette[rng.randi() % color_palette.size()]
	return Color(
		clamp(base_color.r + rng.randf_range(-0.05, 0.05), 0.0, 1.0),
		clamp(base_color.g + rng.randf_range(-0.05, 0.05), 0.0, 1.0),
		clamp(base_color.b + rng.randf_range(-0.05, 0.05), 0.0, 1.0)
	)

## Get a random radius within the type's range
func get_random_radius(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(radius_min, radius_max)

## Get mass multiplier based on radius
func get_mass_multiplier(radius: float, rng: RandomNumberGenerator) -> float:
	var radius_factor = radius / radius_max
	return mass_multiplier_base * radius_factor * rng.randf_range(0.8, 1.2)

## Get habitability with slight variation
func get_habitability_varied(rng: RandomNumberGenerator) -> float:
	return clamp(habitability + rng.randf_range(-0.1, 0.1), 0.0, 1.0)

