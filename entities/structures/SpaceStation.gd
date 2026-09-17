extends RigidBody2D
class_name SpaceStation

const OrbitalMotionClass = preload("res://scripts/OrbitalMotion.gd")

## SpaceStation entity that orbits planets and contains a SpacePort.
## Has gravity like planets and uses the same orbital mechanics.

# Orbital parameters (passed to OrbitalMotion component)
@export var orbital_distance: float = 500.0  # Distance from parent planet center
@export_range(0, 100) var orbital_speed: float = 5.0  # Orbital speed scale (0 = static, 100 = fastest)
@export_range(0, 360) var initial_angle_degrees: float = 0.0  # Starting angle in degrees
var initial_angle: float:
	get: return deg_to_rad(initial_angle_degrees)
@export var eccentricity: float = 0.0  # 0.0 for circular, >0.0 for elliptical (0.0-1.0)
@export var enable_orbiting: bool = true  # Toggle to enable/disable orbiting

var parent_planet: Planet = null
var minimap_target: SpaceStationMinimapTarget = null
var _orbital_motion = null  # Composable orbital component (OrbitalMotion)

## Get current orbital angle (delegates to OrbitalMotion)
var orbital_angle: float:
	get:
		return _orbital_motion.orbital_angle if _orbital_motion else 0.0

func _ready() -> void:
	add_to_group("space_stations")
	
	# Check if parent node is a Planet - setup orbital motion
	var parent = get_parent()
	if parent is Planet:
		parent_planet = parent as Planet
		# Lock rotation for orbiting stations to prevent physics rotation
		lock_rotation = true
		# Create and configure OrbitalMotion component
		_setup_orbital_motion(parent_planet)
	
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
	_orbital_motion.position_mode = OrbitalMotionClass.PositionMode.LOCAL  # Station is child of parent
	_orbital_motion.update_velocity = true  # RigidBody2D needs velocity updates
	add_child(_orbital_motion)
	_orbital_motion.initialize(body)

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

# Orbital mechanics handled by OrbitalMotion child component (no _physics_process needed)
