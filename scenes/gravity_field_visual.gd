extends Node2D
class_name GravityFieldVisual

var planet: Planet = null
@export var base_color: Color = Color(0, 0, 0, 0.0) : set = _set_base_color
@export var outline_width: float = 3.0 : set = _set_outline_width
@export var outline_color: Color = Color(1, 1, 1, 0.25) : set = _set_outline_color

func _ready() -> void:
	planet = NodeUtils.find_parent_of_type(self, Planet)

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

func _draw() -> void:
	var max_radius = _get_radius() * 20
	# Fill
	draw_circle(Vector2.ZERO, max_radius, base_color)

	# Draw 3 rings evenly spaced, with outer rings having lower opacity
	if outline_width > 0.0:
		# 96 segments ~ smooth ring; adjust for perf if needed
		# Inner ring (full opacity)
		var inner_radius = max_radius * (1.0 / 3.0)
		draw_arc(Vector2.ZERO, inner_radius, 0.0, TAU, 96, outline_color, outline_width)
		
		# Middle ring (66% opacity)
		var middle_radius = max_radius * (2.0 / 3.0)
		var middle_color = Color(outline_color.r, outline_color.g, outline_color.b, outline_color.a * 0.66)
		draw_arc(Vector2.ZERO, middle_radius, 0.0, TAU, 96, middle_color, outline_width)
		
		# Outer ring (33% opacity)
		var outer_color = Color(outline_color.r, outline_color.g, outline_color.b, outline_color.a * 0.33)
		draw_arc(Vector2.ZERO, max_radius, 0.0, TAU, 96, outer_color, outline_width)
