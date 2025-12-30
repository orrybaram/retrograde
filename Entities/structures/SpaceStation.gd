extends RigidBody2D
class_name SpaceStation

## SpaceStation entity that orbits planets and contains a SpacePort.
## Has gravity like planets and uses the same orbital mechanics.

# Orbital parameters
@export var orbital_distance: float = 500.0  # Distance from parent planet center
@export_range(0, 100) var orbital_speed: float = 5.0  # Orbital speed scale (0 = static, 100 = fastest)
@export var initial_angle: float = 0.0  # Starting angle in radians
@export var eccentricity: float = 0.0  # 0.0 for circular, >0.0 for elliptical (0.0-1.0)
@export var enable_orbiting: bool = true  # Toggle to enable/disable orbiting

var parent_planet: Planet = null
var orbital_angle: float = 0.0
var minimap_target: SpaceStationMinimapTarget = null

## Convert orbital speed from 0-100 scale to radians per second
## 0 = static, 100 = 0.01 radians/second (fastest)
func _get_orbital_speed_radians_per_second() -> float:
	return (orbital_speed / 100.0) * 0.01

func _ready() -> void:
	add_to_group("space_stations")
	
	# Check if parent node is a Planet
	var parent = get_parent()
	if parent is Planet:
		parent_planet = parent as Planet
		orbital_angle = initial_angle
		# Lock rotation for orbiting stations to prevent physics rotation
		lock_rotation = true
	
	# Register with minimap
	_register_with_minimap.call_deferred()

func _register_with_minimap() -> void:
	var minimap = Minimap.get_instance(get_tree())
	if minimap:
		minimap_target = SpaceStationMinimapTarget.new(self)
		minimap.register_target(minimap_target)

func _exit_tree() -> void:
	# Unregister from minimap
	if minimap_target:
		var minimap = Minimap.get_instance(get_tree())
		if minimap:
			minimap.unregister_target(minimap_target)
		minimap_target = null

func _physics_process(_dt: float) -> void:
	# Handle orbital mechanics if this station has a parent planet
	if parent_planet and enable_orbiting:
		# Get converted orbital speed in radians per second
		var speed_rad_per_sec = _get_orbital_speed_radians_per_second()
		
		# Update orbital angle
		orbital_angle += speed_rad_per_sec * _dt
		
		# Calculate orbital offset (local to parent)
		var orbital_offset: Vector2
		
		if eccentricity == 0.0:
			# Circular orbit
			orbital_offset = Vector2(cos(orbital_angle), sin(orbital_angle)) * orbital_distance
		else:
			# Elliptical orbit using true elliptical formula with focus at parent
			var a = orbital_distance  # semi-major axis
			var e = clamp(eccentricity, 0.0, 0.99)  # clamp eccentricity to valid range
			var r = a * (1.0 - e * e) / (1.0 + e * cos(orbital_angle))
			orbital_offset = Vector2(cos(orbital_angle), sin(orbital_angle)) * r
		
		# Calculate velocity before updating position (tangential to orbit)
		var orbital_velocity_magnitude: float
		if eccentricity == 0.0:
			# Circular orbit: constant speed
			orbital_velocity_magnitude = speed_rad_per_sec * orbital_distance
		else:
			# Elliptical orbit: velocity varies with distance
			var a = orbital_distance
			var e = clamp(eccentricity, 0.0, 0.99)
			var r = a * (1.0 - e * e) / (1.0 + e * cos(orbital_angle))
			# Velocity is higher when closer to parent (periapsis) and lower when farther (apoapsis)
			orbital_velocity_magnitude = speed_rad_per_sec * r
		
		# Velocity is tangential to the orbit (perpendicular to radius vector)
		# Add parent's velocity so station inherits parent planet motion
		var local_orbital_velocity = Vector2(-sin(orbital_angle), cos(orbital_angle)) * orbital_velocity_magnitude
		linear_velocity = parent_planet.linear_velocity + local_orbital_velocity
		
		# Update position (use local position since we're a child in the scene tree)
		position = orbital_offset
