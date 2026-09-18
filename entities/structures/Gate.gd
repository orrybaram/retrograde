extends RigidBody2D
class_name Gate

## The dormant Gate in orbit around a planet. Powering it brings that planet's Module
## online; a Module never goes back offline, so a Gate is powered once and stays powered.
##
## Drawn in code: a ring of dark hull segments with a docking cradle across the gap at
## the bottom. While dormant a single amber blinker is the only thing still running on
## it. Powered, the ring carries the Titan's purple.
##
## Orbits its parent planet with the same OrbitalMotion component the station uses, and
## docks with the same rules as a port: the cradle is the dock surface, the ship comes
## in slow and lined up, and GateDockedState clamps it there.

const OrbitalMotionClass = preload("res://scripts/OrbitalMotion.gd")

## Ring radius; the Gate reads about 200 px across.
const RADIUS := 100.0
## Hull segments around the ring, and the mouth they leave open at the bottom.
const SEGMENTS := 7
const MOUTH_ANGLE := deg_to_rad(52.0)
const RING_WIDTH := 15.0
## Half the width of the docking cradle laid across the mouth.
const CRADLE_HALF := 44.0
## How close the ship has to be to the cradle to dock (the port's range).
const DOCK_DISTANCE := 60.0
## Seconds for the ring to come up to full once the Module is online.
const POWER_UP_TIME := 1.6
## One slow blinker while dormant: seconds per cycle, and the share of it lit.
const BLINK_PERIOD := 2.4
const BLINK_DUTY := 0.18

## What the Titan asks for this Module, in credits.
@export var power_cost: int = 600

# Orbital parameters (passed to OrbitalMotion component)
@export var orbital_distance: float = 10000.0
@export_range(0, 100) var orbital_speed: float = 3.0
@export_range(0, 360) var initial_angle_degrees: float = 0.0
var initial_angle: float:
	get: return deg_to_rad(initial_angle_degrees)
@export var enable_orbiting: bool = true

var parent_planet: Planet = null
var minimap_target: GateMinimapTarget = null

var _orbital_motion = null  # OrbitalMotion
var _clock := 0.0
var _glow := 0.0  # 0 dormant, 1 fully powered; ramps on power-up

## Get current orbital angle (delegates to OrbitalMotion)
var orbital_angle: float:
	get:
		return _orbital_motion.orbital_angle if _orbital_motion else 0.0

func _ready() -> void:
	add_to_group("gates")
	add_to_group("dockable")

	var parent := get_parent()
	if parent is Planet:
		parent_planet = parent as Planet
		lock_rotation = true
		_setup_orbital_motion(parent_planet)

	# A Gate powered in an earlier session is already lit when the world loads
	if is_powered():
		_glow = 1.0

	_register_with_minimap.call_deferred()

func _setup_orbital_motion(body: Node2D) -> void:
	_orbital_motion = OrbitalMotionClass.new()
	_orbital_motion.auto_initialize = false
	_orbital_motion.orbital_distance = orbital_distance
	_orbital_motion.orbital_speed = orbital_speed
	_orbital_motion.initial_angle = initial_angle
	_orbital_motion.eccentricity = 0.0  # circular
	_orbital_motion.enable_orbiting = enable_orbiting
	_orbital_motion.position_mode = OrbitalMotionClass.PositionMode.LOCAL
	_orbital_motion.update_velocity = true
	add_child(_orbital_motion)
	_orbital_motion.initialize(body)

func _register_with_minimap() -> void:
	var minimap := Minimap.get_instance(get_tree())
	if minimap:
		minimap_target = GateMinimapTarget.new(self)
		minimap.register_target(minimap_target)

func _exit_tree() -> void:
	if minimap_target:
		var minimap := Minimap.get_instance(get_tree())
		if minimap:
			minimap.unregister_target(minimap_target)
		minimap_target = null

# --- State -------------------------------------------------------------------

## The planet whose Module this Gate powers; the key both are saved under.
func save_key() -> String:
	return parent_planet.save_key() if parent_planet else ""

func _game_state() -> GameState:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("game_state") as GameState

## True once this Gate's Module is online.
func is_powered() -> bool:
	var gs := _game_state()
	return gs != null and gs.is_gate_powered(save_key())

## Whether the player can pay for it right now.
func can_afford(gs: GameState) -> bool:
	return gs != null and gs.credits >= power_cost

## Pay the cost and bring this planet's Module online. Returns false if it is already
## online or the credits aren't there; nothing is charged in that case.
func power(gs: GameState) -> bool:
	var key := save_key()
	if gs == null or key == "" or gs.is_gate_powered(key) or not can_afford(gs):
		return false
	gs.credits -= power_cost
	gs.mark_gate_powered(key)
	_glow = 0.0
	return true

# --- Dockable ----------------------------------------------------------------

## The cradle sits across the mouth at the bottom of the ring, so a docked ship
## rests inside it.
func get_dock_position() -> Vector2:
	return to_global(Vector2(0, RADIUS))

func get_dock_rotation() -> float:
	return global_rotation

func get_dock_distance() -> float:
	return DOCK_DISTANCE

func get_dock_velocity() -> Vector2:
	return linear_velocity

## The cradle's own frame: the docked ship is held just above its origin.
func get_dock_transform() -> Transform2D:
	return Transform2D(global_rotation, get_dock_position())

# --- Drawing -----------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	if is_powered() and _glow < 1.0:
		_glow = minf(_glow + delta / POWER_UP_TIME, 1.0)
	queue_redraw()

func _draw() -> void:
	var hull := Colors.HULL_DARK.lerp(Colors.TITAN.darkened(0.62), _glow)
	var rim := Colors.HULL_MID.lerp(Colors.TITAN, _glow * 0.6)

	# The ring: hull segments with hairline gaps, open at the bottom for the cradle
	var span := TAU - MOUTH_ANGLE
	var start := PI / 2.0 + MOUTH_ANGLE / 2.0
	var segment := span / SEGMENTS
	var gap := deg_to_rad(2.5)
	for i in SEGMENTS:
		var from := start + segment * i
		var to := from + segment - gap
		draw_arc(Vector2.ZERO, RADIUS, from, to, 24, hull, RING_WIDTH, true)
		draw_arc(Vector2.ZERO, RADIUS - RING_WIDTH / 2.0, from, to, 24, rim, 1.5, true)

	if _glow > 0.0:
		# The Module's own light, bled out past the hull
		for i in 3:
			var halo := RADIUS + RING_WIDTH / 2.0 + i * 5.0
			draw_arc(Vector2.ZERO, halo, start, start + span, 72,
				Color(Colors.TITAN, _glow * 0.22 / (i + 1.0)), 4.0, true)
		draw_arc(Vector2.ZERO, RADIUS, start, start + span, 72,
			Color(Colors.TITAN, _glow * 0.55), 2.0, true)

	_draw_cradle(hull, rim)
	_draw_blinker()

## The cradle across the mouth: a bar the ship sits on, braced back to the ring.
func _draw_cradle(hull: Color, rim: Color) -> void:
	var left := Vector2(-CRADLE_HALF, RADIUS)
	var right := Vector2(CRADLE_HALF, RADIUS)
	draw_line(left, right, hull, 7.0)
	draw_line(left + Vector2(0, -4), right + Vector2(0, -4), rim, 1.0)
	for x in [-CRADLE_HALF + 6.0, CRADLE_HALF - 6.0]:
		draw_line(Vector2(x, RADIUS), Vector2(x * 1.25, RADIUS + 14.0), hull, 4.0)

## While dormant, one slow amber blinker is all that is still running. Powered, it
## holds steady in the Titan's purple.
func _draw_blinker() -> void:
	var at := Vector2(0, -RADIUS)
	if _glow >= 1.0:
		draw_circle(at, 5.0, Color(Colors.TITAN, 0.3))
		draw_circle(at, 2.5, Colors.TITAN)
		return
	var lit := fmod(_clock, BLINK_PERIOD) < BLINK_PERIOD * BLINK_DUTY
	draw_circle(at, 4.0, Color(Colors.PRIMARY, 0.25 if lit else 0.06))
	draw_circle(at, 2.0, Colors.PRIMARY if lit else Colors.PRIMARY_DIM)
