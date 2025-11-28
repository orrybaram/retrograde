extends Node2D
class_name GravityFieldVisual

var planet: Planet = null
@export var base_color: Color = Color(0, 0, 0, 0.0) : set = _set_base_color
@export var outline_width: float = 3.0 : set = _set_outline_width
@export var outline_color: Color = Color(1, 1, 1, 0.25) : set = _set_outline_color
@export var ring_count: int = 3 : set = _set_ring_count
@export var max_radius_multiplier: float = 10.0 : set = _set_max_radius_multiplier

func _set_max_radius_multiplier(v: float) -> void:
	max_radius_multiplier = max(1.0, v)
	queue_redraw()

func _set_ring_count(v: int) -> void:
	ring_count = max(0, v)
	queue_redraw()

func _ready() -> void:
	planet = NodeUtils.find_parent_of_type(self, Planet)

func _get_radius() -> float:
	if planet:
		return planet.radius
	return 160.0  # Fallback

func _get_base_gravity_strength() -> float:
	if planet:
		return planet._get_gravity_strength()
	return 100000.0  # Fallback

func _get_gravity_strength_at_distance(distance: float) -> float:
	# Uses inverse square law: strength = base_strength / (distance * distance)
	var base_strength = _get_base_gravity_strength()
	if distance <= 0.0:
		return base_strength
	return base_strength / (distance * distance)

func _get_distance_for_strength(target_strength: float) -> float:
	# Inverse calculation: distance = sqrt(base_strength / target_strength)
	var base_strength = _get_base_gravity_strength()
	if target_strength <= 0.0:
		return _get_radius() * max_radius_multiplier  # Return max distance
	if target_strength >= base_strength:
		return _get_radius()  # Return min distance (planet surface)
	return sqrt(base_strength / target_strength)

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
	var planet_radius = _get_radius()
	var max_radius = planet_radius * max_radius_multiplier
	# Fill
	draw_circle(Vector2.ZERO, max_radius, base_color)

	# Draw rings based on gravity strength, with outer rings having lower opacity
	if outline_width > 0.0 and ring_count > 0 and planet:
		# Calculate strength at planet surface (reference point)
		var surface_strength = _get_gravity_strength_at_distance(planet_radius)
		
		for i in range(ring_count):
			# Calculate target strength ratio using exponential decay
			# From 100% (inner) to 10% (outer) of surface strength
			# Using: strength_ratio = 0.1 + 0.9 * (1.0 - i / ring_count)
			# Or exponential: strength_ratio = pow(0.1, i / ring_count)
			var strength_ratio = 0.1 + 0.9 * (1.0 - float(i) / float(ring_count))
			var target_strength = surface_strength * strength_ratio
			
			# Calculate radius for this strength
			var ring_radius = _get_distance_for_strength(target_strength)
			
			# Clamp to valid range
			ring_radius = clamp(ring_radius, planet_radius, max_radius)
			
			# Calculate opacity: decreases from inner (full) to outer (lowest)
			var opacity_ratio = 1.0 - (float(i) / float(ring_count))
			var ring_alpha = outline_color.a * opacity_ratio
			
			var ring_color = Color(outline_color.r, outline_color.g, outline_color.b, ring_alpha)
			draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 96, ring_color, outline_width)
