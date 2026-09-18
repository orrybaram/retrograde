extends RigidBody2D
class_name Planet

## Planet entity with OrbitalMotion, gravity field (Area2D), visual rendering,
## and minimap tracking. parent_planet reference enables moon orbits.
## PlanetType drives appearance; PlanetRole drives lore/trade context.

const OrbitalMotionClass = preload("res://scripts/OrbitalMotion.gd")

## Planet types that determine appearance and behavior
enum PlanetType {SUN, GAS_GIANT, ICE_GIANT, EARTH_LIKE, ROCKY, WATER, ICE, BARREN}

## Planet roles that determine lore/cultural significance
enum PlanetRole {NONE, FRONTIER, INDUSTRIAL, RESEARCH, MILITARY, HOMEWORLD}
 
@export var planet_name: String = "Unnamed Planet" ## Name of zthe planet for identification
@export var radius: float = 160.0
@export var gravitational_constant: float = 4.0 # G constant for scaling
@export var color: Color = Colors.PLANET_DEFAULT: set = _set_color
@export var massMultiplier: float = 1.0

# Planet type properties
@export var planet_type: PlanetType = PlanetType.ROCKY
@export var planet_role: PlanetRole = PlanetRole.NONE
@export_range(0.0, 1.0) var habitability: float = 0.0 ## 0.0 = uninhabitable, 1.0 = ideal for life
@export_range(0.0, 1.0) var collision_radius_ratio: float = 1.0 ## Collision radius as ratio of visual radius (gas giants have smaller cores)
@export var gravity_radius_multiplier: float = 3.0 ## How far the gravity field extends (multiplier of planet radius)

# Orbital parameters (passed to OrbitalMotion component)
@export var orbital_distance: float = 500.0 # Distance from parent planet center
@export_range(0, 100) var orbital_speed: float = 5.0 # Orbital speed scale (0 = static, 100 = fastest)
@export var initial_angle: float = 0.0 # Starting angle in radians
@export var eccentricity: float = 0.0 # 0.0 for circular, >0.0 for elliptical (0.0-1.0)
@export var enable_orbiting: bool = true # Toggle to enable/disable orbiting
@export var show_orbit_path: bool = true: set = _set_show_orbit_path # Toggle to show/hide orbit visualization
@export var show_gravity_rings: bool = true: set = _set_show_gravity_rings
@onready var gravity_field: Area2D = $"GravityField"
@onready var orbit_visual: OrbitVisual = $"OrbitVisual"
@onready var gravity_field_visual: GravityFieldVisual = $GravityField/CollisionShape2D/GravityFieldVisual

## Surface gravity readouts divide by this (px/s^2 per unit mass) to show G.
const STANDARD_GRAVITY := 50.0
## How many ore seams a planet grows, and how many a moon grows (moon seams are rich).
const ORE_COUNT := Vector2i(6, 8)
const MOON_ORE_COUNT := Vector2i(3, 4)

var parent_planet: Planet = null
var minimap_target: PlanetMinimapTarget = null
var _orbital_motion = null # Composable orbital component (OrbitalMotion)

## Get current orbital angle (delegates to OrbitalMotion)
var orbital_angle: float:
	get:
		return _orbital_motion.orbital_angle if _orbital_motion else 0.0
	set(value):
		if _orbital_motion:
			_orbital_motion.orbital_angle = value
			_orbital_motion.initial_angle = value
			_orbital_motion.orbital_start_time = Time.get_ticks_msec() / 1000.0

func _set_show_gravity_rings(v: bool) -> void:
	show_gravity_rings = v
	if gravity_field_visual:
		gravity_field_visual.visible = v

func _set_color(c: Color) -> void:
	color = c
	# Update the visual if it exists
	var visual = get_node_or_null("PlanetVisual") as PlanetVisual
	if visual:
		visual.base_color = c

func _set_show_orbit_path(v: bool) -> void:
	show_orbit_path = v
	if orbit_visual:
		orbit_visual.show_orbit = v

func _get_gravity_strength() -> float:
	return mass * gravitational_constant

## Pull at the surface in G (STANDARD_GRAVITY px/s^2 of gravity force per unit mass).
func surface_gravity() -> float:
	return _get_gravity_strength() / (radius * radius) / STANDARD_GRAVITY

## How far the gravity field extends from the centre.
func field_radius() -> float:
	return radius * gravity_radius_multiplier

## How close the ship has to be for the Planetary Scanner to work: inner orbit, the
## first gravity ring clear of the surface.
func scan_radius() -> float:
	var rings: int = gravity_field_visual.ring_count if gravity_field_visual else 6
	return GravityFieldVisual.inner_orbit_radius(radius, field_radius(), rings)

## Stable key for saves: "Name", or "Parent/Name" for moons.
func save_key() -> String:
	return Save._get_planet_key(self)

func is_moon() -> bool:
	return parent_planet != null and parent_planet.planet_type != PlanetType.SUN

## True once the Planetary Scanner has mapped this planet (the sun is never scanned).
func is_scanned() -> bool:
	if not is_inside_tree():
		return false
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	return gs != null and gs.is_planet_scanned(save_key())

## Ore seams under this planet's surface (revealed once it's scanned).
func get_ore_deposits() -> Array[OreDeposit]:
	var ores: Array[OreDeposit] = []
	for child in get_children():
		if child is OreDeposit:
			ores.append(child)
	return ores

## Grow this planet's ore seams: MOON_ORE_COUNT rich ones on a moon, ORE_COUNT on a
## planet, none on the sun or a gas giant (no ground to land on). Seeded from the
## planet's save key, so a planet has the same seams in the same places every session.
func _spawn_ore() -> void:
	if planet_type == PlanetType.SUN or planet_type == PlanetType.GAS_GIANT:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(save_key())
	var span := MOON_ORE_COUNT if is_moon() else ORE_COUNT
	var count := rng.randi_range(span.x, span.y)
	# Spread the seams apart so one landing is never in reach of two
	var gap := 360.0 / count
	for i in count:
		var ore := OreDeposit.new()
		ore.name = "Ore%d" % i
		ore.ore_index = i
		ore.rich = is_moon()
		ore.angle_degrees = fmod(rng.randf_range(0.0, gap) + gap * i, 360.0)
		add_child(ore)

func _ready() -> void:
	add_to_group("planets")
	
	mass = massMultiplier * 1000000
	
	# Set initial color on visual
	var visual = get_node_or_null("PlanetVisual") as PlanetVisual
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
	
	_spawn_ore()

	# Register with minimap
	_register_with_minimap.call_deferred()

func _setup_orbital_motion(body: Node2D) -> void:
	_orbital_motion = OrbitalMotionClass.new()
	_orbital_motion.auto_initialize = false # We'll initialize manually
	_orbital_motion.orbital_distance = orbital_distance
	_orbital_motion.orbital_speed = orbital_speed
	_orbital_motion.initial_angle = initial_angle
	_orbital_motion.eccentricity = eccentricity
	_orbital_motion.enable_orbiting = enable_orbiting
	_orbital_motion.position_mode = OrbitalMotionClass.PositionMode.LOCAL # Planet is child of parent
	_orbital_motion.update_velocity = true # RigidBody2D needs velocity updates
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
