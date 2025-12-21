extends RigidBody2D
class_name Planet

## Planet types that determine appearance and behavior
enum PlanetType { SUN, GAS_GIANT, ICE_GIANT, EARTH_LIKE, ROCKY, WATER, ICE, BARREN }
 
@export var radius: float = 160.0
@export var gravitational_constant: float = 4.0  # G constant for scaling
@export var color: Color = Color(0.15, 0.6, 0.9) : set = _set_color
@export var massMultiplier: float = 1.0

# Planet type properties
@export var planet_type: PlanetType = PlanetType.ROCKY
@export_range(0.0, 1.0) var habitability: float = 0.0  ## 0.0 = uninhabitable, 1.0 = ideal for life
@export_range(0.0, 1.0) var collision_radius_ratio: float = 1.0  ## Collision radius as ratio of visual radius (gas giants have smaller cores)

# Orbital parameters
@export var orbital_distance: float = 500.0  # Distance from parent planet center
@export var orbital_speed: float = 0.0001  # Angular velocity in radians per second
@export var initial_angle: float = 0.0  # Starting angle in radians
@export var eccentricity: float = 0.0  # 0.0 for circular, >0.0 for elliptical (0.0-1.0)
@export var enable_orbiting: bool = true  # Toggle to enable/disable orbiting
@export var show_orbit_path: bool = true : set = _set_show_orbit_path  # Toggle to show/hide orbit visualization
@export var show_gravity_rings: bool = true : set = _set_show_gravity_rings
@onready var gravity_field: Area2D = $"GravityField"
@onready var orbit_visual: OrbitVisual = $"OrbitVisual"
@onready var gravity_field_visual: GravityFieldVisual = $GravityField/CollisionShape2D/GravityFieldVisual

var parent_planet: Planet = null
var orbital_angle: float = 0.0
var minimap_target: PlanetMinimapTarget = null

func _set_show_gravity_rings(v: bool) -> void:
	show_gravity_rings = v
	if gravity_field_visual:
		gravity_field_visual.visible = v

func _set_color(c: Color) -> void: 
	color = c
	# Update the visual if it exists
	var visual = get_node_or_null("Circle") as PlanetVisual
	if visual:
		visual.base_color = c

func _set_show_orbit_path(v: bool) -> void:
	show_orbit_path = v
	if orbit_visual:
		orbit_visual.show_orbit = v

func _get_gravity_strength() -> float:
	return mass * gravitational_constant

func _ready() -> void:
	add_to_group("planets")
	
	mass = massMultiplier * 1000000
	
	# Set initial color on visual
	var visual = get_node_or_null("Circle") as PlanetVisual
	if visual:
		visual.base_color = color
		
	if gravity_field_visual:
		gravity_field_visual.visible = show_gravity_rings
	
	# Check if parent node is a Planet
	var parent = get_parent()
	if parent is Planet:
		parent_planet = parent as Planet
		orbital_angle = initial_angle
		# Lock rotation for orbiting planets to prevent physics rotation
		lock_rotation = true
		# Update orbit visual if it exists
		if orbit_visual:
			orbit_visual.show_orbit = show_orbit_path
	
	# Register with minimap
	_register_with_minimap.call_deferred()

func _register_with_minimap() -> void:
	var minimap = Minimap.get_instance(get_tree())
	if minimap:
		minimap_target = PlanetMinimapTarget.new(self)
		minimap.register_target(minimap_target)

func _exit_tree() -> void:
	# Unregister from minimap
	if minimap_target:
		var minimap = Minimap.get_instance(get_tree())
		if minimap:
			minimap.unregister_target(minimap_target)
		minimap_target = null

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
