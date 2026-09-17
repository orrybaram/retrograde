extends Node2D
class_name OreDeposit

## A seam of ore sitting just under a planet's surface: a few subtle hexagons that only
## show once the Planetary Scanner has mapped the planet. Planets grow their own seams
## (Planet._spawn_ore, seeded from the planet's key, so they land in the same places
## every session). The seam is a child of its Planet, so it rides the orbit.
##
## Land on the plain surface anywhere within REACH of a seam to drill it (see Touchdown).
## `rich` seams (moons) run deeper and roll better gems. A dig spends the seam: its
## hexes dim and can't be drilled until they refill (REGROW_TIME of play,
## RICH_REGROW_TIME when rich; timers live in GameState, and are never shown as a clock).
##
## Deeper scans and deeper digs are a later iteration; for now every seam sits near the
## surface and is reached from the ground above it.

## How far along the surface the ship may land from the seam's centre and still drill it.
const REACH := 150.0
const DEPTH_MIN := 22.0  # how far under the surface the hexes sit
const DEPTH_MAX := 110.0
const CLUSTER := 70.0  # radius of the scatter around the seam's centre
const HEX_MIN := 9.0
const HEX_MAX := 20.0
const HEX_COUNT := Vector2i(2, 4)
const RICH_HEX_COUNT := Vector2i(4, 6)
const FILL_ALPHA := 0.16
const LINE_ALPHA := 0.55
const LINE_WIDTH := 1.5
const SHIMMER := 0.12  # how much the seam breathes
const SHIMMER_SPEED := 1.6
const REVEAL_TIME := 0.9
const PING_RADIUS := 170.0
const REGROW_TIME := 300.0
const RICH_REGROW_TIME := 450.0

## Where on the planet, in degrees (0 = the planet's +x side).
@export_range(0.0, 360.0) var angle_degrees: float = 0.0
## Richer seams (moons) run deeper and roll better gems.
@export var rich: bool = false
## Index within its planet; part of the save key.
@export var ore_index: int = 0

var planet: Planet = null
var minimap_target: OreMinimapTarget = null

var _hexes: Array[Dictionary] = []  # {pos: Vector2 (local), size: float, phase: float}
var _revealed := false
var _reveal_time := 0.0  # counts up after reveal, for the ping
var _tracking: OreTrackingTarget = null
var _gs: GameState = null
var _was_spent := false

func _ready() -> void:
	add_to_group("ore_deposits")
	planet = get_parent() as Planet
	z_index = 1  # over the planet disc, under the ship
	if planet:
		var normal_angle := deg_to_rad(angle_degrees)
		position = Vector2.from_angle(normal_angle) * surface_radius()
		rotation = normal_angle
		_hexes = shape_hexes(rich, hash(ore_id()))
	EventBus.planet_scanned.connect(_on_planet_scanned)
	EventBus.planets_restored.connect(refresh)
	EventBus.ship_respawned.connect(refresh)
	refresh()
	_register_with_minimap.call_deferred()

func _exit_tree() -> void:
	if minimap_target:
		var minimap := Minimap.get_instance(get_tree())
		if minimap:
			minimap.unregister_target(minimap_target)
		minimap_target = null

## The hexagons of one seam, in the seam's local space (local +x points out of the
## surface, so the hexes sit at negative x). Seeded, so a seam looks the same every run.
static func shape_hexes(is_rich: bool, seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var span := RICH_HEX_COUNT if is_rich else HEX_COUNT
	var centre := Vector2(-(DEPTH_MIN + DEPTH_MAX) / 2.0, 0.0)
	var hexes: Array[Dictionary] = []
	for i in rng.randi_range(span.x, span.y):
		# Scattered evenly through a disc around the seam's centre, not strung out in a line
		var at := centre + Vector2.from_angle(rng.randf() * TAU) * (sqrt(rng.randf()) * CLUSTER)
		hexes.append({
			"pos": Vector2(-clampf(-at.x, DEPTH_MIN, DEPTH_MAX), at.y),
			"size": rng.randf_range(HEX_MIN, HEX_MAX) * (1.15 if is_rich else 1.0),
			"turn": rng.randf() * TAU,
			"phase": rng.randf() * TAU,
		})
	return hexes

## Planet key + index, stable across sessions (for saves).
func ore_id() -> String:
	return "%s#%d" % [planet.save_key(), ore_index]

func surface_radius() -> float:
	return planet.radius * planet.collision_radius_ratio

## Outward surface normal (world space).
func normal() -> Vector2:
	return Vector2.from_angle(global_rotation)

## How far to either side the ship may set down, as an angle on the surface.
func reach_angle() -> float:
	return REACH / surface_radius()

## World velocity of the seam (the planet's orbital velocity).
func velocity() -> Vector2:
	return planet.linear_velocity if planet else Vector2.ZERO

func is_revealed() -> bool:
	return _revealed

func regrow_time() -> float:
	return RICH_REGROW_TIME if rich else REGROW_TIME

## Seconds until a dug-out seam refills (0 when it can be drilled). Never shown as a clock.
func regrow_left() -> float:
	var gs := _game_state()
	return gs.ore_regrow_left(ore_id()) if gs else 0.0

func is_spent() -> bool:
	return regrow_left() > 0.0

## A dig finished here: dim the seam and start its regrow timer.
func spend() -> void:
	var gs := _game_state()
	if not gs:
		return
	gs.spend_ore(ore_id(), regrow_time())
	_was_spent = true
	queue_redraw()

func tracking_target() -> OreTrackingTarget:
	if not _tracking:
		_tracking = OreTrackingTarget.new(self)
	return _tracking

## Show or hide to match whether the planet has been scanned.
func refresh() -> void:
	_set_revealed(planet != null and planet.is_scanned(), false)

func ore_color() -> Color:
	return Colors.PRIMARY_DIM if is_spent() else Colors.PRIMARY

func _game_state() -> GameState:
	if not is_instance_valid(_gs) and is_inside_tree():
		_gs = get_tree().get_first_node_in_group("game_state") as GameState
	return _gs if is_instance_valid(_gs) else null

func _on_planet_scanned(scanned: Planet) -> void:
	if scanned == planet:
		_set_revealed(true, true)

func _set_revealed(value: bool, animate: bool) -> void:
	_revealed = value
	_was_spent = is_spent()
	visible = value
	_reveal_time = 0.0 if animate else REVEAL_TIME
	queue_redraw()

func _process(delta: float) -> void:
	if not _revealed:
		return
	var spent := is_spent()
	if _was_spent and not spent:
		_reveal_time = 0.0  # refilled: show it surfacing again
	_was_spent = spent
	_reveal_time += delta
	queue_redraw()

func _draw() -> void:
	var t := clampf(_reveal_time / REVEAL_TIME, 0.0, 1.0)
	var color := ore_color()
	for hex in _hexes:
		var breathe: float = 1.0 + SHIMMER * sin(_reveal_time * SHIMMER_SPEED + hex["phase"])
		var points := hex_points(hex["pos"], hex["size"] * ease(t, 0.4) * breathe, hex["turn"])
		draw_colored_polygon(points, Color(color, FILL_ALPHA * t))
		points.append(points[0])
		draw_polyline(points, Color(color, LINE_ALPHA * t), LINE_WIDTH)
	# The scan surfacing the seam
	if _reveal_time < REVEAL_TIME:
		draw_arc(Vector2.ZERO, PING_RADIUS * t, 0.0, TAU, 48, Color(Colors.PRIMARY, 1.0 - t), 2.0)

## A hexagon of `size` around `at`, turned by `turn` radians.
static func hex_points(at: Vector2, size: float, turn := 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 6:
		points.append(at + Vector2.from_angle(turn + TAU * i / 6.0) * size)
	return points

func _register_with_minimap() -> void:
	var minimap := Minimap.get_instance(get_tree())
	if minimap:
		minimap_target = OreMinimapTarget.new(self)
		minimap.register_target(minimap_target)
