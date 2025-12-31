extends RigidBody2D
class_name Planet

const OrbitalMotionClass = preload("res://scripts/OrbitalMotion.gd")

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

# Orbital parameters (passed to OrbitalMotion component)
@export var orbital_distance: float = 500.0  # Distance from parent planet center
@export_range(0, 100) var orbital_speed: float = 5.0  # Orbital speed scale (0 = static, 100 = fastest)
@export var initial_angle: float = 0.0  # Starting angle in radians
@export var eccentricity: float = 0.0  # 0.0 for circular, >0.0 for elliptical (0.0-1.0)
@export var enable_orbiting: bool = true  # Toggle to enable/disable orbiting
@export var show_orbit_path: bool = true : set = _set_show_orbit_path  # Toggle to show/hide orbit visualization
@export var show_gravity_rings: bool = true : set = _set_show_gravity_rings
@onready var gravity_field: Area2D = $"GravityField"
@onready var orbit_visual: OrbitVisual = $"OrbitVisual"
@onready var gravity_field_visual: GravityFieldVisual = $GravityField/CollisionShape2D/GravityFieldVisual

var parent_planet: Planet = null
var minimap_target: PlanetMinimapTarget = null
var _orbital_motion = null  # Composable orbital component (OrbitalMotion)

## Get current orbital angle (delegates to OrbitalMotion)
var orbital_angle: float:
	get:
		return _orbital_motion.orbital_angle if _orbital_motion else 0.0

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
	
	# Check if parent node is a Planet - setup orbital motion
	var parent = get_parent()
	if parent is Planet:
		parent_planet = parent as Planet
		# Lock rotation for orbiting planets to prevent physics rotation
		lock_rotation = true
		# Create and configure OrbitalMotion component
		_setup_orbital_motion(parent_planet)
		# Update orbit visual if it exists
		if orbit_visual:
			orbit_visual.show_orbit = show_orbit_path
	
	# Register with minimap
	_register_with_minimap.call_deferred()

func _setup_orbital_motion(body: Node2D) -> void:
	_orbital_motion = OrbitalMotionClass.new()
	_orbital_motion.auto_initialize = false  # We'll initialize manually
	_orbital_motion.orbital_distance = orbital_distance
	_orbital_motion.orbital_speed = orbital_speed
	_orbital_motion.initial_angle = initial_angle
	_orbital_motion.eccentricity = eccentricity
	_orbital_motion.enable_orbiting = enable_orbiting
	_orbital_motion.position_mode = OrbitalMotionClass.PositionMode.LOCAL  # Planet is child of parent
	_orbital_motion.update_velocity = true  # RigidBody2D needs velocity updates
	add_child(_orbital_motion)
	_orbital_motion.initialize(body)

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
	# Orbital mechanics handled by OrbitalMotion child component
	
	# Apply gravity to ships
	for body in gravity_field.get_overlapping_bodies():
		if body is Ship:
			var gravity_strength = _get_gravity_strength()
			var dir = global_position.direction_to(body.global_position)
			var dist = global_position.distance_to(body.global_position)
			var force_mag = gravity_strength / max(dist * dist, 1.0)

			body.apply_force(-dir * force_mag)
