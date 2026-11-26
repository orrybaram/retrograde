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
## Soft halo around the disc, in the planet's own color. Alpha at the planet's edge.
@export_range(0.0, 1.0) var glow_strength: float = 0.12 : set = _set_glow_strength
## Halo thickness as a fraction of the planet radius.
@export_range(0.0, 1.0) var glow_size: float = 0.18 : set = _set_glow_size
@export var glow_segments: int = 64
## Glow is multiplied by up to `glow_near_boost` at `glow_near_distance` from the sun,
## easing to 1x at `glow_far_distance`.
@export var glow_near_boost: float = 1.6
@export var glow_near_distance: float = 50000.0
@export var glow_far_distance: float = 250000.0
## Halo multiplier on the side facing the sun.
@export var glow_lit_gain: float = 2.5 : set = _set_glow_lit_gain
## Halo multiplier on the side facing away from the sun.
@export var glow_dark_gain: float = 0.35 : set = _set_glow_dark_gain

## Current sun-proximity multiplier on glow_strength.
var _glow_boost: float = 1.0

@export_group("Sun")
## Corona reach as a multiple of the sun's radius.
@export var sun_corona_size: float = 2.2
## Corona alpha right at the sun's rim.
@export_range(0.0, 1.0) var sun_corona_strength: float = 0.9
@export var sun_ray_count: int = 28
## Longest ray as a fraction of the sun's radius.
@export var sun_ray_length: float = 0.7
@export_group("")

var _sun_time: float = 0.0

func _ready() -> void:
	planet = NodeUtils.find_parent_of_type(self, Planet)
	if planet:
		# Use planet's color if available
		base_color = planet.color
	if _is_sun():
		# Own additive material; the scene's material is shared with other nodes.
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = additive
		if not Engine.is_editor_hint():
			var glare := SunGlare.new()
			glare.sun = self
			add_child(glare)

func _process(delta: float) -> void:
	if _is_sun():
		# Corona breathes and rays drift, so the sun redraws every frame
		_sun_time += delta
		queue_redraw()
		return
	if Engine.is_editor_hint():
		return
	var sun := _get_sun()
	if sun == null:
		return
	var to_sun := sun.global_position - global_position
	var boost := glow_boost_for(to_sun.length(), glow_near_distance, glow_far_distance, glow_near_boost)
	if absf(boost - _glow_boost) > 0.01:
		_glow_boost = boost
		queue_redraw()
	if to_sun.is_zero_approx():
		return
	# Convert to local space so the shadow stays correct if the body rotates.
	var local_dir := to_sun.rotated(-global_rotation).normalized()
	if absf(local_dir.angle_to(light_dir)) > LIGHT_REDRAW_THRESHOLD:
		light_dir = local_dir

func _is_sun() -> bool:
	return planet != null and planet.planet_type == Planet.PlanetType.SUN

func _casts_shadow() -> bool:
	return not _is_sun()

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

func _set_glow_strength(v: float) -> void:
	glow_strength = clampf(v, 0.0, 1.0)
	queue_redraw()

func _set_glow_size(v: float) -> void:
	glow_size = clampf(v, 0.0, 1.0)
	queue_redraw()

func _set_glow_lit_gain(v: float) -> void:
	glow_lit_gain = maxf(0.0, v)
	queue_redraw()

func _set_glow_dark_gain(v: float) -> void:
	glow_dark_gain = maxf(0.0, v)
	queue_redraw()

## Halo multiplier for the rim point in direction `dir`: `lit_gain` facing `to_light`,
## `dark_gain` facing away, eased so the brightness bunches up on the sunward side.
static func glow_side_gain(dir: Vector2, to_light: Vector2, lit_gain: float, dark_gain: float) -> float:
	if to_light.is_zero_approx():
		return 1.0
	var t := (dir.normalized().dot(to_light.normalized()) + 1.0) * 0.5
	return lerpf(dark_gain, lit_gain, t * t)

## Glow multiplier for a body `distance` from the sun: `near_boost` at or inside
## `near`, 1.0 at or beyond `far`, linear in between.
static func glow_boost_for(distance: float, near: float, far: float, near_boost: float) -> float:
	if far <= near:
		return near_boost if distance <= near else 1.0
	var t := clampf((distance - near) / (far - near), 0.0, 1.0)
	return lerpf(near_boost, 1.0, t)

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

## Appends a ring-shaped radial gradient to `canvas_item` in a single draw call.
## `stops` is an Array of [radius: float, color: Color], ordered by increasing radius.
## A first stop at radius 0 produces a filled disc. `gains` (optional, one per segment)
## scales alpha around the ring.
static func add_radial_gradient(canvas_item: RID, stops: Array, segments: int, gains: PackedFloat32Array = PackedFloat32Array()) -> void:
	if stops.size() < 2:
		return
	var n := maxi(segments, 8)
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var dirs: Array[Vector2] = []
	for i in n:
		dirs.append(Vector2.from_angle(TAU * i / n))
	var use_gains := gains.size() == n
	for stop in stops:
		for i in n:
			points.append(dirs[i] * float(stop[0]))
			var c: Color = stop[1]
			if use_gains:
				c.a = clampf(c.a * gains[i], 0.0, 1.0)
			colors.append(c)
	for ring in stops.size() - 1:
		var a0 := ring * n
		var b0 := (ring + 1) * n
		for i in n:
			var j := (i + 1) % n
			indices.append_array([a0 + i, a0 + j, b0 + j, a0 + i, b0 + j, b0 + i])
	RenderingServer.canvas_item_add_triangle_array(canvas_item, indices, points, colors)

## Screen glare alpha for a camera `distance` from the center of a sun of `radius`:
## `max_alpha` at the surface, easing (cubic) to 0 at `reach` radii from the center.
static func glare_alpha_for(distance: float, radius: float, reach: float, max_alpha: float) -> float:
	if radius <= 0.0 or reach <= 1.0:
		return 0.0
	var t := clampf((distance - radius) / (radius * (reach - 1.0)), 0.0, 1.0)
	return max_alpha * pow(1.0 - t, 3.0)

func _draw() -> void:
	var radius = _get_radius()

	if _is_sun():
		_draw_sun(radius)
		return

	# Halo sits behind the disc
	if glow_strength > 0.0 and glow_size > 0.0:
		_draw_glow(radius)

	# Fill
	draw_circle(Vector2.ZERO, radius, base_color)

	# Night side: flat darker tint of the planet color
	if shadow_strength > 0.0:
		var shadow_color := base_color.lerp(Colors.SPACE_BG, shadow_strength)
		shadow_color.a = base_color.a
		var poly := build_shadow_polygon(radius, light_dir, terminator_curve, shadow_segments)
		if poly.size() >= 3:
			draw_colored_polygon(poly, shadow_color)

	# Outline ring (arc)
	if outline_width > 0.0:
		# 96 segments ~ smooth ring; adjust for perf if needed
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, outline_color, outline_width)

## Halo that fades from `glow_strength` alpha at the rim to 0 outside,
## with an eased two-band falloff. Brighter on the sun-facing side.
func _draw_glow(radius: float) -> void:
	var outer := radius * (1.0 + glow_size)
	var strength := glow_strength * _glow_boost
	var n := maxi(glow_segments, 8)
	var gains := PackedFloat32Array()
	gains.resize(n)
	for i in n:
		gains[i] = glow_side_gain(Vector2.from_angle(TAU * i / n), light_dir, glow_lit_gain, glow_dark_gain)
	add_radial_gradient(get_canvas_item(), [
		[radius, Color(base_color, base_color.a * strength)],
		[lerpf(radius, outer, 0.35), Color(base_color, base_color.a * strength * 0.35)],
		[outer, Color(base_color, 0.0)],
	], n, gains)

## Additive corona, drifting rays, and a disc that burns white toward the center.
func _draw_sun(radius: float) -> void:
	var ci := get_canvas_item()
	var hot := Colors.CREAM
	var warm := base_color
	var ember := Colors.ORANGE
	var pulse := 1.0 + 0.04 * sin(_sun_time * 0.9) + 0.02 * sin(_sun_time * 2.3)
	var reach := radius * sun_corona_size * pulse
	var s := sun_corona_strength

	# Corona: bright rim bleeding into a long warm falloff
	add_radial_gradient(ci, [
		[radius, Color(hot, s)],
		[lerpf(radius, reach, 0.08), Color(warm, s * 0.7)],
		[lerpf(radius, reach, 0.25), Color(warm, s * 0.35)],
		[lerpf(radius, reach, 0.55), Color(ember, s * 0.12)],
		[reach, Color(ember, 0.0)],
	], 96)

	# Rays: thin wedges off the rim, each breathing on its own phase
	var n := maxi(sun_ray_count, 0)
	for i in n:
		var phase := float(i) * 2.399
		var angle := TAU * float(i) / float(n) + _sun_time * 0.015 + 0.08 * sin(phase)
		var long_ray := 1.0 if i % 2 == 0 else 0.55
		var length := radius * sun_ray_length * long_ray * (0.65 + 0.35 * sin(_sun_time * 0.6 + phase))
		var half_width := PI / float(n) * 0.35
		var base_a := Vector2.from_angle(angle - half_width) * radius * 0.98
		var base_b := Vector2.from_angle(angle + half_width) * radius * 0.98
		var tip := Vector2.from_angle(angle) * (radius + length)
		draw_polygon(
			PackedVector2Array([base_a, tip, base_b]),
			PackedColorArray([Color(hot, 0.45), Color(warm, 0.0), Color(hot, 0.45)]))

	# Disc: warm limb, white-hot core
	add_radial_gradient(ci, [
		[0.0, hot],
		[radius * 0.55, hot],
		[radius * 0.85, hot.lerp(warm, 0.5)],
		[radius, warm],
	], 96)
