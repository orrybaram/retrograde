extends Control
class_name Minimap

## The ship's sonar: a beam sweeps the scope, and whatever it crosses
## comes back as an echo that fades until the next pass. There are two kinds of contact:
##
## - **Solid echoes.** Every body, station, Gate, hull and chunk of scrap comes back as the
##   same mustard smudge, stretched a little along the sweep. Size is the only thing that
##   tells them apart: an echo is as big as the thing is (planets are discs at true scale),
##   down to ECHO_MIN_PX. Reading the scope is a skill, not a legend.
## - **Pings.** Things that answer (MinimapTarget.is_ping): when the beam crosses one it
##   sends a hollow ring out, and goes quiet until the next pass.
##
## Home (a station) is the one echo with its own shape, a diamond, so it can be picked out.
## And anything that turns up after the game has started - scrap a Sweep finds, a Gate
## once its planet is scanned - rings out once with its first echo: a discovery.
##
## Echoes are phosphor: each is stamped where the beam found it and fades in place, so a
## moving contact leaves stale returns behind. The ship at the centre, the nav target's
## blue diamond (the ship's own plot, not a return), the range rings and the rim are never
## swept. Each target only says where it is, how big it is, and whether it pings.

## The sweep
const SWEEP_PERIOD := 5.0
const SWEEP_CLOCKWISE := true
const AFTERGLOW := 3.0
const AFTERGLOW_FLOOR := 0.11
const BEAM_TRAIL_DEG := 90.0
const BEAM_ALPHA := 0.42
const BEAM_WIDTH_PX := 1.7
const HIT_FLASH := 0.74
const HIT_FLASH_TIME := 0.2
## Echoes
const ECHO_MIN_PX := 2.2
## Home's diamond is never smaller than this, half-diagonal px.
const HOME_MIN_PX := 4.5
const ECHO_SCALE := 1.0
const ECHO_SMEAR := 1.0
const ECHO_JITTER_PX := 3.0
const GRAIN := 1.0
const GRAIN_DOTS := 260
## Pings
const PING_DURATION := 2.0
const PING_RINGS := 1
const PING_REACH_PX := 10.0
const PING_ALPHA := 0.8
const PING_LINE_PX := 1.0
## A planet's disc is drawn this much bigger than true scale, so small ones still read.
const BODY_SCALE := 1.3

## The display radius of the minimap in pixels
@export var display_radius: float = 70.0

## The world range that the minimap covers (in world units)
@export var world_range: float = 10000.0

@export var ring_color: Color = Colors.PRIMARY_MEDIUM
@export var border_color: Color = Colors.UI_BORDER
@export var ship_color: Color = Colors.CREAM
@export var nav_color: Color = Colors.NAV
## The Void is hatched in the same red, at the same spacing and strength, as on the chart.
@export var void_color: Color = Colors.DANGER
## Matches SystemMap.HATCH_SPACING_PX, so both read as the same hatching.
const VOID_HATCH_SPACING := 13.0

const SHIP_SIZE := 7.0
const NAV_SIZE := 9.0
const NAV_POINTER_SIZE := 4.0 # the rim arrow that only gives the bearing
const EDGE_INSET := 11.0 # how far inside the rim pinned echoes sit
const NAV_MARGIN := 4.0 # clearance the nav diamond keeps around the echo it rings

## Whether to rotate the minimap with the ship's heading
@export var rotate_with_ship: bool = false

## Number of radar rings to display
@export var ring_count: int = 4

var targets: Array[MinimapTarget] = []
var ship: Ship = null

## Echoes on the glass: {target, world (position when found), jitter, time, radius, ping, body}
var _echoes: Array[Dictionary] = []
var _last_beam := 0.0
## Targets the scope has known about (instance id -> true): whatever was already there, or
## has been seen. One that turns up after that is a discovery, and its first echo pings.
var _known := {}
## Discoveries waiting for the beam to reach them.
var _undiscovered := {}
## Its own dice: the scope's jitter and grain must never move gameplay rolls.
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("minimap")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(display_radius * 2 + 20, display_radius * 2 + 20)
	_rng.seed = 7
	_last_beam = beam_angle(now())

func _process(_delta: float) -> void:
	if not ship or not is_instance_valid(ship):
		ship = get_tree().get_first_node_in_group("ship") as Ship
	note_discoveries()
	if ship and is_instance_valid(ship):
		_sweep()
	queue_redraw()

# --- The sweep -----------------------------------------------------------------

## Where the beam points at `time`, 0..TAU in the minimap's own frame (0 = +x, screen right).
static func beam_angle(time: float) -> float:
	var a := fmod(time / SWEEP_PERIOD * TAU, TAU)
	return a if SWEEP_CLOCKWISE else fmod(TAU - a, TAU)

## Whether the beam passed `bearing` on its way from `from` to `to` (one frame's worth).
static func beam_crossed(from: float, to: float, bearing: float) -> bool:
	var span := fposmod(to - from, TAU) if SWEEP_CLOCKWISE else fposmod(from - to, TAU)
	var off := fposmod(bearing - from, TAU) if SWEEP_CLOCKWISE else fposmod(from - bearing, TAU)
	return span < PI and off <= span

## How bright an echo `age` seconds old is: the afterglow, down to the floor.
static func glow(age: float) -> float:
	var k := maxf(0.0, 1.0 - age / AFTERGLOW)
	return AFTERGLOW_FLOOR + (1.0 - AFTERGLOW_FLOOR) * k * k

## An echo's radius on the scope, px: as big as the thing is, never smaller than the minimum.
func echo_radius(target: MinimapTarget) -> float:
	var r := target.echo_world_radius() / world_range * display_radius
	if target.is_body():
		return maxf(r * BODY_SCALE, ECHO_MIN_PX)
	return maxf(r * ECHO_SCALE, ECHO_MIN_PX)

## Stamp an echo for everything the beam passed over since last frame, and let the old
## ones go once they have faded to the floor and the beam has been round again.
func _sweep() -> void:
	var t := now()
	var beam := beam_angle(t)
	var center := size / 2.0
	var ship_rotation := ship.rotation if rotate_with_ship else 0.0
	for target in targets:
		if not target or not target.is_minimap_visible():
			continue
		var id := target.get_instance_id()
		var world := target.get_minimap_position()
		var at = _to_minimap(center, world, ship_rotation, target.pins_to_edge())
		if at == null:
			continue
		var bearing := fposmod(((at as Vector2) - center).angle(), TAU)
		if not beam_crossed(_last_beam, beam, bearing):
			continue
		var jitter := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf() * ECHO_JITTER_PX
		_echoes.append({
			"target": target, "world": world, "jitter": jitter, "time": t,
			"radius": echo_radius(target), "ping": target.is_ping(), "body": target.is_body(),
			"pin": target.pins_to_edge(), "diamond": target.echo_is_diamond(),
			"discovered": _undiscovered.erase(id),
		})
	var keep := SWEEP_PERIOD * 1.05 + AFTERGLOW
	_echoes = _echoes.filter(func(e: Dictionary) -> bool: return t - e["time"] <= keep)
	_last_beam = beam

## Anything visible now that the scope has never known about is a discovery: its first
## echo will ring out.
func note_discoveries() -> void:
	for target in targets:
		if not target or not target.is_minimap_visible():
			continue
		var id := target.get_instance_id()
		if not _known.has(id):
			_known[id] = true
			_undiscovered[id] = true

## Whether `target` is waiting for the beam to discover it.
func is_undiscovered(target: MinimapTarget) -> bool:
	return _undiscovered.has(target.get_instance_id())

## Every echo still on the glass (for tests and playtests).
func echoes() -> Array[Dictionary]:
	return _echoes

# --- Drawing -------------------------------------------------------------------

func _draw() -> void:
	var center := size / 2.0
	for i in range(1, ring_count + 1):
		draw_arc(center, display_radius * float(i) / ring_count, 0, TAU, 64, ring_color, 1.0)
	if not ship or not is_instance_valid(ship):
		draw_arc(center, display_radius, 0, TAU, 64, border_color, 2.0)
		return
	var ship_rotation := ship.rotation if rotate_with_ship else 0.0
	_draw_void(center, ship_rotation)
	var t := now()
	var beam := beam_angle(t)
	_draw_trail(center, beam)
	for e in _echoes:
		_draw_echo(center, e, t - e["time"], ship_rotation)
	_draw_grain(center)
	draw_line(center, center + Vector2.from_angle(beam) * display_radius, Color(Colors.PRIMARY, BEAM_ALPHA), BEAM_WIDTH_PX, true)
	_draw_nav_target(center, ship_rotation)
	draw_arc(center, display_radius, 0, TAU, 64, border_color, 2.0)
	draw_chevron(self, center, SHIP_SIZE, -PI / 2 if rotate_with_ship else ship.rotation, ship_color)

## The glow behind the beam, fading back over BEAM_TRAIL_DEG.
func _draw_trail(center: Vector2, beam: float) -> void:
	var trail := deg_to_rad(BEAM_TRAIL_DEG)
	var steps := maxi(4, int(BEAM_TRAIL_DEG / 3.0))
	var back := -1.0 if SWEEP_CLOCKWISE else 1.0
	for i in steps:
		var f0 := float(i) / steps
		var f1 := float(i + 1) / steps
		var a0 := beam + back * f0 * trail
		var a1 := beam + back * f1 * trail
		var wedge := PackedVector2Array([center,
			center + Vector2.from_angle(a0) * display_radius,
			center + Vector2.from_angle(a1) * display_radius])
		draw_colored_polygon(wedge, Color(Colors.PRIMARY, 0.14 * BEAM_ALPHA * (1.0 - f0)))

func _draw_echo(center: Vector2, e: Dictionary, age: float, ship_rotation: float) -> void:
	var at = _to_minimap(center, e["world"], ship_rotation, e["pin"])
	if at == null:
		return
	var pos: Vector2 = at + e["jitter"]
	var a := glow(age)
	var r: float = e["radius"]
	if e["ping"]:
		_draw_ping(pos, age, a)
		return
	if e["discovered"]:
		_draw_rings(pos, age)
	if e["diamond"]:
		var h := maxf(r, HOME_MIN_PX)
		var points := PackedVector2Array([pos + Vector2(0, -h), pos + Vector2(h, 0), pos + Vector2(0, h), pos + Vector2(-h, 0)])
		var halo := PackedVector2Array()
		for p in points:
			halo.append(pos + (p - pos) * 1.6)
		draw_colored_polygon(halo, Color(Colors.PRIMARY, 0.18 * a))
		draw_colored_polygon(points, Color(Colors.PRIMARY, 0.95 * a))
		if age < HIT_FLASH_TIME:
			draw_colored_polygon(points, Color(Colors.CREAM, HIT_FLASH * (1.0 - age / HIT_FLASH_TIME)))
		return
	if e["body"]:
		draw_circle(pos, r, Color(Colors.PRIMARY, 0.22 * a))
		draw_arc(pos, r, 0, TAU, 32, Color(Colors.PRIMARY, 0.75 * a), maxf(1.0, r * 0.12), true)
		return
	# A smudge along the sweep: the arc of the echo's own range, a little each way
	var rel := pos - center
	var d := maxf(rel.length(), 0.001)
	var th := rel.angle()
	var half := minf(0.9, r * ECHO_SMEAR / d)
	draw_arc(center, d, th - half, th + half, 6, Color(Colors.PRIMARY, 0.22 * a), r * 2.6)
	draw_arc(center, d, th - half * 0.7, th + half * 0.7, 6, Color(Colors.PRIMARY, 0.95 * a), r * 1.3)
	if age < HIT_FLASH_TIME:
		draw_circle(pos, r * 0.9, Color(Colors.CREAM, HIT_FLASH * (1.0 - age / HIT_FLASH_TIME)))

## A ping: hollow rings going out from where the beam found it, and a dot left behind.
func _draw_ping(pos: Vector2, age: float, a: float) -> void:
	_draw_rings(pos, age)
	draw_circle(pos, 0.8, Color(Colors.PRIMARY, PING_ALPHA * 0.7 * a))

## The rings of a ping, `age` seconds after the beam set them off.
func _draw_rings(pos: Vector2, age: float) -> void:
	for i in PING_RINGS:
		var f := (age - i * PING_DURATION * 0.25) / PING_DURATION
		if f < 0.0 or f > 1.0:
			continue
		draw_arc(pos, 0.5 + f * PING_REACH_PX, 0, TAU, 24, Color(Colors.PRIMARY, PING_ALPHA * (1.0 - f)), PING_LINE_PX, true)

## Static on the glass.
func _draw_grain(center: Vector2) -> void:
	if GRAIN <= 0.0:
		return
	for i in int(GRAIN_DOTS * GRAIN):
		var at := center + Vector2.from_angle(_rng.randf() * TAU) * sqrt(_rng.randf()) * display_radius
		var s := 0.35 + _rng.randf() * 0.4
		draw_rect(Rect2(at, Vector2(s, s)), Color(Colors.PRIMARY, 0.05 + _rng.randf() * 0.12 * GRAIN))

## The Void, as the chart draws it (SystemMap._draw_void) but unlabelled: diagonals past
## EDGE_RADIUS, doubled past DEEP_RADIUS, and the boundary line, breathing red while the
## ship is out there. All of it clipped to the minimap's disc.
func _draw_void(center: Vector2, ship_rotation: float) -> void:
	var sun := _to_minimap_unclamped(center, VoidZone.sun_position(), ship_rotation)
	var px_per_unit := display_radius / world_range
	var edge := VoidZone.EDGE_RADIUS * px_per_unit
	var deep := VoidZone.DEEP_RADIUS * px_per_unit
	var alarm := VoidZone.shroud
	var spacing := VOID_HATCH_SPACING
	var band := void_hatching(center, display_radius, sun, edge, spacing, 0.0)
	if not band.is_empty():
		draw_multiline(band, Color(void_color, 0.11 + 0.07 * alarm), 1.0)
	var deeper := void_hatching(center, display_radius, sun, deep, spacing, spacing / 2.0)
	if not deeper.is_empty():
		draw_multiline(deeper, Color(void_color, 0.09 + 0.07 * alarm), 1.0)
	var boundary := Color(void_color, lerpf(0.3, 0.75, alarm * (0.6 + 0.4 * sin(now() * 4.0))))
	_draw_void_boundary(center, sun, edge, boundary)
	_draw_void_boundary(center, sun, deep, Color(void_color, boundary.a * 0.4))

## Diagonal hatching across the disc at `center` (radius `disc`), kept only outside the
## circle of `radius` around `sun`: where the Void is. Point pairs for draw_multiline.
static func void_hatching(center: Vector2, disc: float, sun: Vector2, radius: float, spacing: float, phase: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	# The whole disc inside the system: nothing to hatch
	if center.distance_to(sun) + disc <= radius:
		return points
	var direction := Vector2.from_angle(PI / 4.0)
	var normal := direction.orthogonal()
	var offset := -disc + phase
	while offset <= disc:
		# The chord of this diagonal inside the disc, then the parts of it past the edge
		var half := sqrt(maxf(disc * disc - offset * offset, 0.0))
		if half > 0.5:
			var start := center + normal * offset - direction * half
			_append_outside_circle(points, start, direction, half * 2.0, sun, radius)
		offset += spacing
	return points

## The parts of start -> start + direction * length outside the circle, as point pairs
## (the same clip SystemMap uses for the chart's hatching).
static func _append_outside_circle(points: PackedVector2Array, start: Vector2, direction: Vector2, length: float, center: Vector2, radius: float) -> void:
	var to_center := start - center
	var b := to_center.dot(direction)
	var discriminant := b * b - (to_center.length_squared() - radius * radius)
	if discriminant <= 0.0:
		if to_center.length() > radius:
			points.append(start)
			points.append(start + direction * length)
		return
	var root := sqrt(discriminant)
	var t_in := clampf(-b - root, 0.0, length)
	var t_out := clampf(-b + root, 0.0, length)
	if t_in > 0.5:
		points.append(start)
		points.append(start + direction * t_in)
	if t_out < length - 0.5:
		points.append(start + direction * t_out)
		points.append(start + direction * length)

## The stretch of a Void boundary circle that crosses the disc.
func _draw_void_boundary(center: Vector2, sun: Vector2, radius: float, color: Color) -> void:
	var d := center.distance_to(sun)
	if d <= 0.0 or absf(d - radius) >= display_radius:
		return
	var cos_half := clampf((d * d + radius * radius - display_radius * display_radius) / (2.0 * d * radius), -1.0, 1.0)
	var half := acos(cos_half)
	var mid := (center - sun).angle()
	var points := PackedVector2Array()
	for i in 25:
		points.append(sun + Vector2.from_angle(mid - half + 2.0 * half * i / 24.0) * radius)
	draw_polyline(points, color, 1.0, true)

## A world position on the minimap's plane, however far off the disc it falls.
func _to_minimap_unclamped(center: Vector2, world_pos: Vector2, ship_rotation: float) -> Vector2:
	var relative_pos := world_pos - ship.global_position
	if rotate_with_ship:
		relative_pos = relative_pos.rotated(-ship_rotation - PI / 2)
	return center + relative_pos / world_range * display_radius

## Where to put a world position on the minimap (pinned to the rim when out of range).
func _to_minimap(center: Vector2, world_pos: Vector2, ship_rotation: float, pin: bool) -> Variant:
	var relative_pos := world_pos - ship.global_position
	if rotate_with_ship:
		relative_pos = relative_pos.rotated(-ship_rotation - PI / 2)
	var minimap_pos := relative_pos / world_range * display_radius
	if minimap_pos.length() > display_radius - EDGE_INSET:
		if not pin:
			if minimap_pos.length() > display_radius:
				return null
			return center + minimap_pos
		minimap_pos = minimap_pos.normalized() * (display_radius - EDGE_INSET)
	return center + minimap_pos

## The nav target (waypoint, or home): a blue diamond outline around whatever it sits on,
## live and never swept - it is the ship's own plot, not a return. Out of range, a small
## arrow on the rim gives the bearing.
func _draw_nav_target(center: Vector2, ship_rotation: float) -> void:
	var target := NavSystem.get_target()
	if not target:
		return
	var in_range = _to_minimap(center, target.get_position(), ship_rotation, false)
	if in_range == null or ((in_range as Vector2) - center).length() > display_radius - EDGE_INSET:
		var pinned: Vector2 = _to_minimap(center, target.get_position(), ship_rotation, true)
		draw_pointer(self, pinned, NAV_POINTER_SIZE, (pinned - center).angle(), nav_color)
		return
	var pos: Vector2 = in_range
	var marker_size := _nav_marker_size(target)
	var points := PackedVector2Array([
		pos + Vector2(0, -marker_size), pos + Vector2(marker_size, 0),
		pos + Vector2(0, marker_size), pos + Vector2(-marker_size, 0), pos + Vector2(0, -marker_size),
	])
	draw_polyline(points, nav_color, 1.5)
	draw_circle(pos, 1.2, nav_color)

## Big enough to ring the echo the nav target shares its spot with.
func _nav_marker_size(target: TrackingTarget) -> float:
	var node := (target as NodeTrackingTarget).node if target is NodeTrackingTarget else null
	if node == null:
		return NAV_SIZE
	for t in targets:
		if t and t.is_minimap_visible() and t.get_minimap_node() == node:
			return maxf(NAV_SIZE, echo_radius(t) + NAV_MARGIN)
	return NAV_SIZE

## Present time in seconds, for the sweep.
static func now() -> float:
	return Time.get_ticks_msec() / 1000.0

## Ship-like arrowhead pointing along `angle` (0 = +x).
static func draw_chevron(canvas: CanvasItem, pos: Vector2, marker_size: float, angle: float, color: Color) -> void:
	var points := PackedVector2Array()
	for p in [Vector2(1.0, 0.0), Vector2(-0.8, 0.7), Vector2(-0.4, 0.0), Vector2(-0.8, -0.7)]:
		points.append(pos + (p * marker_size).rotated(angle))
	canvas.draw_colored_polygon(points, color)

## Small solid triangle pointing along `angle` (0 = +x). A bearing, not a thing.
static func draw_pointer(canvas: CanvasItem, pos: Vector2, marker_size: float, angle: float, color: Color) -> void:
	var points := PackedVector2Array()
	for p in [Vector2(1.0, 0.0), Vector2(-0.7, 0.85), Vector2(-0.7, -0.85)]:
		points.append(pos + (p * marker_size).rotated(angle))
	canvas.draw_colored_polygon(points, color)

## Register a target to be displayed on the minimap
## Whatever is already visible when it registers is simply there; only something that
## becomes visible later is a discovery.
func register_target(target: MinimapTarget) -> void:
	if target and not targets.has(target):
		targets.append(target)
		if target.is_minimap_visible():
			_known[target.get_instance_id()] = true

## Unregister a target from the minimap
func unregister_target(target: MinimapTarget) -> void:
	targets.erase(target)
	_known.erase(target.get_instance_id())
	_undiscovered.erase(target.get_instance_id())
	_echoes = _echoes.filter(func(e: Dictionary) -> bool: return e["target"] != target)

## Get the minimap singleton (convenience method)
static func get_instance(tree: SceneTree) -> Minimap:
	return tree.get_first_node_in_group("minimap") as Minimap
