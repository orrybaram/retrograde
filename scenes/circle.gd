extends Node2D
class_name PlanetVisual

var planet: Planet = null
@export var base_color: Color = Color(0.15, 0.6, 0.9) : set = _set_base_color
@export var outline_width: float = 3.0 : set = _set_outline_width
@export var outline_color: Color = Color(1, 1, 1, 0.25) : set = _set_outline_color

# Simple lighting fakery: a soft dark overlay offset opposite the light direction.
@export var light_dir: Vector2 = Vector2.RIGHT : set = _set_light_dir
@export var shadow_strength: float = 0.1 : set = _set_shadow_strength   # 0..1
@export var shadow_offset_scale: float = 0.02 : set = _set_shadow_offset_scale  # 0..1

func _ready() -> void:
	planet = get_parent() as Planet
	if planet:
		# Connect to property changes if needed, or just redraw periodically
		# For now, we'll get radius dynamically in _draw()
		pass

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

func _set_shadow_offset_scale(v: float) -> void:
	shadow_offset_scale = clampf(v, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var radius = _get_radius()
	# Fill
	draw_circle(Vector2.ZERO, radius, base_color)

	# Soft "terminator" shadow as a large translucent circle, offset opposite the light
	if shadow_strength > 0.0:
		var offset = -light_dir.normalized() * radius * shadow_offset_scale
		var shadow = Color(0, 0, 0, shadow_strength)
		draw_circle(offset, radius, shadow)

	# Outline ring (arc)
	if outline_width > 0.0:
		# 96 segments ~ smooth ring; adjust for perf if needed
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, outline_color, outline_width)
