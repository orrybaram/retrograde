@tool
extends Node2D
class_name PlanetVisual

## Draws a planet disc with a sun-facing day side and a flat-colored night side.
## The night side is the half of the disc facing away from the sun. The line between
## them (the terminator) curves slightly so the shadow reads as a crescent on a sphere.

## Redraw once the light direction has swung by more than this many radians.
const LIGHT_REDRAW_THRESHOLD := 0.002

var planet: Planet = null
var _sun: Node2D = null
@export var base_color: Color = Colors.PLANET_DEFAULT : set = _set_base_color
@export var outline_width: float = 3.0 : set = _set_outline_width
@export var outline_color: Color = Colors.OUTLINE : set = _set_outline_color

## Direction toward the light, in this node's local space. Tracks the sun at runtime;
## the exported value is only used when no sun exists (e.g. in the editor).
@export var light_dir: Vector2 = Vector2.RIGHT : set = _set_light_dir
## How far the night side is blended toward the space background (0 = no shadow).
@export_range(0.0, 1.0) var shadow_strength: float = 0.55 : set = _set_shadow_strength
## Terminator curvature. 0 = straight line (exact half), >0 bulges into the night side
## (thinner crescent shadow), <0 bulges into the day side (fatter shadow).
@export_range(-0.95, 0.95) var terminator_curve: float = 0.25 : set = _set_terminator_curve
@export var shadow_segments: int = 48

func _ready() -> void:
	planet = NodeUtils.find_parent_of_type(self, Planet)
	if planet:
		# Use planet's color if available
		base_color = planet.color

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not _casts_shadow():
		return
	var sun := _get_sun()
	if sun == null:
		return
	var to_sun := sun.global_position - global_position
	if to_sun.is_zero_approx():
		return
	# Convert to local space so the shadow stays correct if the body rotates.
	var local_dir := to_sun.rotated(-global_rotation).normalized()
	if absf(local_dir.angle_to(light_dir)) > LIGHT_REDRAW_THRESHOLD:
		light_dir = local_dir

func _casts_shadow() -> bool:
	return planet == null or planet.planet_type != Planet.PlanetType.SUN

func _get_sun() -> Node2D:
	if is_instance_valid(_sun):
		return _sun
	_sun = null
	for node in get_tree().get_nodes_in_group("planets"):
		if node is Planet and node.planet_type == Planet.PlanetType.SUN:
			_sun = node
			break
	return _sun

func _get_radius() -> float:
	if planet:
		return planet.radius
	return 160.0  # Fallback

func _set_base_color(c: Color) -> void:
	base_color = c
	queue_redraw()

func _set_outline_width(v: float) -> void:
	outline_width = max(0.0, v)
	queue_redraw()

func _set_outline_color(c: Color) -> void:
	outline_color = c
	queue_redraw()

func _set_light_dir(v: Vector2) -> void:
	light_dir = v.normalized()
	queue_redraw()

func _set_shadow_strength(v: float) -> void:
	shadow_strength = clampf(v, 0.0, 1.0)
	queue_redraw()

func _set_terminator_curve(v: float) -> void:
	terminator_curve = clampf(v, -0.95, 0.95)
	queue_redraw()

## Night-side polygon for a disc of `radius` lit from `to_light` (need not be normalized).
## Outer edge: the half-circle facing away from the light. Inner edge: a half-ellipse
## whose depth along the light axis is `curve * radius`.
static func build_shadow_polygon(radius: float, to_light: Vector2, curve: float, segments: int = 48) -> PackedVector2Array:
	var points := PackedVector2Array()
	if radius <= 0.0 or to_light.is_zero_approx():
		return points
	var away := -to_light.normalized()   # Axis pointing into the night side
	var side := away.orthogonal()
	var n := maxi(segments, 4)
	# Limb arc, one pole to the other through the anti-sun point
	for i in n + 1:
		var t := -PI / 2.0 + PI * float(i) / float(n)
		points.append((away * cos(t) + side * sin(t)) * radius)
	# Terminator back to the start pole (endpoints already present)
	for i in range(n - 1, 0, -1):
		var t := -PI / 2.0 + PI * float(i) / float(n)
		points.append((away * cos(t) * curve + side * sin(t)) * radius)
	return points

func _draw() -> void:
	var radius = _get_radius()

	# Fill
	draw_circle(Vector2.ZERO, radius, base_color)

	# Night side: flat darker tint of the planet color
	if shadow_strength > 0.0 and _casts_shadow():
		var shadow_color := base_color.lerp(Colors.SPACE_BG, shadow_strength)
		shadow_color.a = base_color.a
		var poly := build_shadow_polygon(radius, light_dir, terminator_curve, shadow_segments)
		if poly.size() >= 3:
			draw_colored_polygon(poly, shadow_color)

	# Outline ring (arc)
	if outline_width > 0.0:
		# 96 segments ~ smooth ring; adjust for perf if needed
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, outline_color, outline_width)
