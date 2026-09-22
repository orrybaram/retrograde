extends Control
class_name Minimap

## Radar-style minimap that displays the ship and nearby tracked entities.
## Each MinimapTarget draws its own marker (see draw_marker), using the shape helpers
## below, so markers can look like what they stand for.

## The display radius of the minimap in pixels
@export var display_radius: float = 70.0

## The world range that the minimap covers (in world units)
@export var world_range: float = 10000.0

## Planet size scaling
@export var planet_size_multiplier: float = 1.3  ## Multiplier to make planets visible on minimap

## Colors
@export var background_color: Color = Colors.UI_BACKGROUND_LIGHT
@export var border_color: Color = Colors.UI_BORDER
@export var ring_color: Color = Colors.PRIMARY_MEDIUM
@export var ship_color: Color = Colors.CREAM
@export var nav_color: Color = Colors.NAV
## The Void is hatched in the same red, at the same spacing and strength, as on the chart.
@export var void_color: Color = Colors.DANGER
## Matches SystemMap.HATCH_SPACING_PX, so both read as the same hatching.
const VOID_HATCH_SPACING := 13.0

const SHIP_SIZE := 7.0
const NAV_SIZE := 9.0
const NAV_POINTER_SIZE := 4.0 # the rim arrow that only gives the bearing
const EDGE_INSET := 11.0 # how far inside the rim pinned markers sit
const NAV_MARGIN := 4.0 # clearance the nav diamond keeps around the marker it rings

## Whether to rotate the minimap with the ship's heading
@export var rotate_with_ship: bool = false

## Number of radar rings to display
@export var ring_count: int = 4

var targets: Array[MinimapTarget] = []
var ship: Ship = null

func _ready() -> void:
	add_to_group("minimap")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Set minimum size based on display radius
	custom_minimum_size = Vector2(display_radius * 2 + 20, display_radius * 2 + 20)

func _process(_delta: float) -> void:
	# Find ship if not set
	if not ship or not is_instance_valid(ship):
		ship = get_tree().get_first_node_in_group("ship") as Ship
	
	# Redraw every frame
	queue_redraw()

func _draw() -> void:
	var center = size / 2.0
	
	# Draw radar rings
	for i in range(1, ring_count + 1):
		var ring_radius = display_radius * (float(i) / float(ring_count))
		draw_arc(center, ring_radius, 0, TAU, 64, ring_color, 1.0)
	
	var ship_rotation = ship.rotation if ship and is_instance_valid(ship) and rotate_with_ship else 0.0
	if ship and is_instance_valid(ship):
		_draw_void(center, ship_rotation)

	# Draw border
	draw_arc(center, display_radius, 0, TAU, 64, border_color, 2.0)
	
	# Draw cardinal direction indicators
	_draw_cardinal_indicators(center)
	
	if not ship or not is_instance_valid(ship):
		return
	
	# Draw all visible targets
	var visible_targets: Array[MinimapTarget] = []
	for target in targets:
		if target and target.is_minimap_visible():
			visible_targets.append(target)
	
	# Sort by priority (lower priority drawn first, so higher priority is on top)
	visible_targets.sort_custom(func(a, b): return a.get_minimap_priority() < b.get_minimap_priority())
	
	# Nav diamond goes underneath, so it frames markers instead of covering them
	_draw_nav_target(center, ship_rotation, visible_targets)

	for target in visible_targets:
		_draw_target(center, target, ship_rotation)

	# Draw ship indicator at center (always on top)
	_draw_ship_indicator(center)

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

func _draw_cardinal_indicators(center: Vector2) -> void:
	var indicator_distance = display_radius + 8
	var font = ThemeDB.fallback_font
	var font_size = 8
	
	# Only draw if not rotating (otherwise directions don't make sense)
	if not rotate_with_ship:
		# N, E, S, W
		var directions = ["N", "E", "S", "W"]
		var angles = [-PI/2, 0, PI/2, PI]
		
		for i in range(4):
			var pos = center + Vector2(cos(angles[i]), sin(angles[i])) * indicator_distance
			var text_size = font.get_string_size(directions[i], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			draw_string(font, pos - text_size / 2, directions[i], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, border_color)

func _draw_target(center: Vector2, target: MinimapTarget, ship_rotation: float) -> void:
	var target_pos = target.get_minimap_position()
	var ship_pos = ship.global_position
	
	# Calculate relative position
	var relative_pos = target_pos - ship_pos
	
	# Rotate if needed (negative rotation + offset to align "up" with ship forward)
	if rotate_with_ship:
		relative_pos = relative_pos.rotated(-ship_rotation - PI/2)
	
	# Scale to minimap coordinates
	var minimap_pos = relative_pos / world_range * display_radius
	
	var target_size = target.get_minimap_size()
	var view_rotation: float = -ship_rotation - PI / 2 if rotate_with_ship else 0.0

	if minimap_pos.length() > display_radius + target_size:
		if not target.pins_to_edge():
			return
		# Out of range: hold it on the rim, pointing the way
		minimap_pos = minimap_pos.normalized() * (display_radius - EDGE_INSET)

	target.draw_marker(self, center + minimap_pos, target_size, view_rotation)

func _draw_ship_indicator(center: Vector2) -> void:
	# The player's ship: a cream arrowhead along its heading
	var heading := -PI / 2 if rotate_with_ship else ship.rotation
	draw_chevron(self, center, SHIP_SIZE, heading, ship_color)

## Where to put a world position on the minimap (pinned to the rim when out of range).
func _to_minimap(center: Vector2, world_pos: Vector2, ship_rotation: float, pin: bool) -> Variant:
	var relative_pos := world_pos - ship.global_position
	if rotate_with_ship:
		relative_pos = relative_pos.rotated(-ship_rotation - PI / 2)
	var minimap_pos := relative_pos / world_range * display_radius
	if minimap_pos.length() > display_radius - EDGE_INSET:
		if not pin:
			return null
		minimap_pos = minimap_pos.normalized() * (display_radius - EDGE_INSET)
	return center + minimap_pos

## The nav target (waypoint, or home): a blue diamond outline around whatever it sits
## on. It is drawn under the markers, so it takes the size of whatever it sits on —
## otherwise tracking a planet close up buries the diamond inside its disc.
## Still out of range, there is nothing to ring: a small arrow on the rim just gives
## the bearing until the thing itself comes onto the map.
func _draw_nav_target(center: Vector2, ship_rotation: float, visible_targets: Array[MinimapTarget]) -> void:
	var target := NavSystem.get_target()
	if not target:
		return
	var in_range = _to_minimap(center, target.get_position(), ship_rotation, false)
	if in_range == null:
		var pinned: Vector2 = _to_minimap(center, target.get_position(), ship_rotation, true)
		draw_pointer(self, pinned, NAV_POINTER_SIZE, (pinned - center).angle(), nav_color)
		return
	var pos: Vector2 = in_range
	var marker_size := _nav_marker_size(target, visible_targets)
	var points := PackedVector2Array([
		pos + Vector2(0, -marker_size), pos + Vector2(marker_size, 0),
		pos + Vector2(0, marker_size), pos + Vector2(-marker_size, 0), pos + Vector2(0, -marker_size),
	])
	draw_polyline(points, nav_color, 1.5)
	draw_circle(pos, 1.2, nav_color)

## Big enough to ring the marker the nav target shares its spot with.
func _nav_marker_size(target: TrackingTarget, visible_targets: Array[MinimapTarget]) -> float:
	var node := (target as NodeTrackingTarget).node if target is NodeTrackingTarget else null
	if node == null:
		return NAV_SIZE
	for t in visible_targets:
		if t.get_minimap_node() == node:
			return maxf(NAV_SIZE, t.get_minimap_size() + NAV_MARGIN)
	return NAV_SIZE

## Present time in seconds, for blinking/pulsing markers.
static func now() -> float:
	return Time.get_ticks_msec() / 1000.0

## Ship-like arrowhead pointing along `angle` (0 = +x).
static func draw_chevron(canvas: CanvasItem, pos: Vector2, marker_size: float, angle: float, color: Color) -> void:
	var points := PackedVector2Array()
	for p in [Vector2(1.0, 0.0), Vector2(-0.8, 0.7), Vector2(-0.4, 0.0), Vector2(-0.8, -0.7)]:
		points.append(pos + (p * marker_size).rotated(angle))
	canvas.draw_colored_polygon(points, color)

## Small solid triangle pointing along `angle` (0 = +x). A bearing, not a thing:
## blunter than the ship arrowhead so the two never read as the same mark.
static func draw_pointer(canvas: CanvasItem, pos: Vector2, marker_size: float, angle: float, color: Color) -> void:
	var points := PackedVector2Array()
	for p in [Vector2(1.0, 0.0), Vector2(-0.7, 0.85), Vector2(-0.7, -0.85)]:
		points.append(pos + (p * marker_size).rotated(angle))
	canvas.draw_colored_polygon(points, color)

static func draw_diamond(canvas: CanvasItem, pos: Vector2, marker_size: float, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(0, -marker_size), pos + Vector2(marker_size, 0),
		pos + Vector2(0, marker_size), pos + Vector2(-marker_size, 0),
	]), color)

## Small irregular chunk (a squashed quad) turned by `angle`.
static func draw_fleck(canvas: CanvasItem, pos: Vector2, marker_size: float, angle: float, color: Color) -> void:
	var points := PackedVector2Array()
	for p in [Vector2(1.0, -0.3), Vector2(0.2, 0.9), Vector2(-1.0, 0.4), Vector2(-0.4, -0.8)]:
		points.append(pos + (p * marker_size).rotated(angle))
	canvas.draw_colored_polygon(points, color)

## Register a target to be displayed on the minimap
func register_target(target: MinimapTarget) -> void:
	if target and not targets.has(target):
		targets.append(target)

## Unregister a target from the minimap
func unregister_target(target: MinimapTarget) -> void:
	targets.erase(target)

## Get the minimap singleton (convenience method)
static func get_instance(tree: SceneTree) -> Minimap:
	var minimap = tree.get_first_node_in_group("minimap")
	return minimap as Minimap
