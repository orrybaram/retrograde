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

const SHIP_SIZE := 7.0
const NAV_SIZE := 9.0
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
	
	# Draw border
	draw_arc(center, display_radius, 0, TAU, 64, border_color, 2.0)
	
	# Draw cardinal direction indicators
	_draw_cardinal_indicators(center)
	
	if not ship or not is_instance_valid(ship):
		return
	
	var ship_rotation = ship.rotation if rotate_with_ship else 0.0
	
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

## The nav target (waypoint, or home): a blue diamond outline, held on the rim when far.
## It is drawn under the markers, so it takes the size of whatever it sits on —
## otherwise tracking a planet close up buries the diamond inside its disc.
func _draw_nav_target(center: Vector2, ship_rotation: float, visible_targets: Array[MinimapTarget]) -> void:
	var target := NavSystem.get_target()
	if not target:
		return
	# Held on the rim, the diamond stands alone — there is no marker out there to
	# ring, so it goes back to its own size rather than a planet's.
	var in_range = _to_minimap(center, target.get_position(), ship_rotation, false)
	var pos: Vector2 = in_range if in_range != null else _to_minimap(center, target.get_position(), ship_rotation, true)
	var marker_size := _nav_marker_size(target, visible_targets) if in_range != null else NAV_SIZE
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
