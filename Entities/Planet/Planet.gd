extends RigidBody2D
class_name Planet
 
@export var radius: float = 160.0
@export var gravitational_constant: float = 4.0  # G constant for scaling
@export var color: Color = Color(0.15, 0.6, 0.9) : set = _set_color

# Orbital parameters
@export var orbital_distance: float = 500.0  # Distance from parent planet center
@export var orbital_speed: float = 0.05  # Angular velocity in radians per second
@export var initial_angle: float = 0.0  # Starting angle in radians
@export var eccentricity: float = 0.0  # 0.0 for circular, >0.0 for elliptical (0.0-1.0)
@export var enable_orbiting: bool = true  # Toggle to enable/disable orbiting

@onready var gravity_field: Area2D = $"GravityField"

var parent_planet: Planet = null
var orbital_angle: float = 0.0

func _set_color(c: Color) -> void: 
	color = c
	# Update the visual if it exists
	var visual = get_node_or_null("Circle") as PlanetVisual
	if visual:
		visual.base_color = c

func _get_gravity_strength() -> float:
	return mass * gravitational_constant

func _ready() -> void:
	add_to_group("planets")
	# Set initial color on visual
	var visual = get_node_or_null("Circle") as PlanetVisual
	if visual:
		visual.base_color = color
	
	# Check if parent node is a Planet
	var parent = get_parent()
	if parent is Planet:
		parent_planet = parent as Planet
		orbital_angle = initial_angle
		# Lock rotation for orbiting planets to prevent physics rotation
		lock_rotation = true

func _physics_process(_dt: float) -> void:
	# Handle orbital mechanics if this planet has a parent planet
	if parent_planet and enable_orbiting:
		# Update orbital angle
		orbital_angle += orbital_speed * _dt
		
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
			orbital_velocity_magnitude = orbital_speed * orbital_distance
		else:
			# Elliptical orbit: velocity varies with distance
			var a = orbital_distance
			var e = clamp(eccentricity, 0.0, 0.99)
			var r = a * (1.0 - e * e) / (1.0 + e * cos(orbital_angle))
			# Velocity is higher when closer to parent (periapsis) and lower when farther (apoapsis)
			orbital_velocity_magnitude = orbital_speed * r
		
		# Velocity is tangential to the orbit (perpendicular to radius vector)
		linear_velocity = Vector2(-sin(orbital_angle), cos(orbital_angle)) * orbital_velocity_magnitude
		
		# Update position (use local position since we're a child in the scene tree)
		position = orbital_offset
	
	# Apply gravity to ships
	for body in gravity_field.get_overlapping_bodies():
		if body is Ship:
			var gravity_strength = _get_gravity_strength()
			var dir = global_position.direction_to(body.global_position)
			var dist = global_position.distance_to(body.global_position)
			var force_mag = gravity_strength / max(dist * dist, 1.0)

			body.apply_force(-dir * force_mag)
