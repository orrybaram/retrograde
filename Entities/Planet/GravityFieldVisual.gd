extends Node2D
class_name GravityFieldVisual

var planet: Planet = null
@export var base_color: Color = Color(0, 0, 0, 0.0): set = _set_base_color
@export var outline_width: float = 3.0: set = _set_outline_width
@export var outline_color: Color = Color(1, 1, 1, 0.25): set = _set_outline_color
@export var ring_count: int = 6: set = _set_ring_count

func _set_ring_count(v: int) -> void:
	ring_count = max(0, v)
	queue_redraw()

func _ready() -> void:
	planet = NodeUtils.find_parent_of_type(self, Planet)

func _get_radius() -> float:
	if planet:
		return planet.radius
	return 160.0 # Fallback

func _get_base_gravity_strength() -> float:
	if planet:
		return planet._get_gravity_strength()
	return 100000.0 # Fallback

func _get_gravity_strength_at_distance(distance: float) -> float:
	# Uses inverse square law: strength = base_strength / (distance * distance)
	var base_strength = _get_base_gravity_strength()
	if distance <= 0.0:
		return base_strength
	return base_strength / (distance * distance)

func _get_distance_for_strength(target_strength: float) -> float:
	# Inverse calculation: distance = sqrt(base_strength / target_strength)
	var base_strength = _get_base_gravity_strength()
	var max_radius_multiplier = planet.gravity_radius_multiplier if planet else 20.0
	if target_strength <= 0.0:
		return _get_radius() * max_radius_multiplier # Return max distance
	if target_strength >= base_strength:
		return _get_radius() # Return min distance (planet surface)
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
	# Get max_radius_multiplier from Planet to ensure visual matches physics
	var max_radius_multiplier = planet.gravity_radius_multiplier if planet else 20.0
	var max_radius = planet_radius * max_radius_multiplier
	var min_radius = planet_radius - 100.0
	# Fill
	draw_circle(Vector2.ZERO, max_radius, base_color)

	# Draw rings with outermost ring matching the Area2D collision boundary
	if outline_width > 0.0 and ring_count > 0 and planet:
		for i in range(ring_count):
			# Evenly distribute rings from planet surface to max gravity radius
			# i=0 is innermost (closest to planet), i=ring_count-1 is outermost (at collision boundary)
			var t = float(i) / float(ring_count - 1) if ring_count > 1 else 1.0
			var ring_radius = lerp(min_radius, max_radius, t)
			
			# Calculate opacity: decreases from inner (full) to outer (lowest)
			var opacity_ratio = 1.0 - (float(i) / float(ring_count))
			var ring_alpha = outline_color.a * opacity_ratio
			
			var ring_color = Color(outline_color.r, outline_color.g, outline_color.b, ring_alpha)
			draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 96, ring_color, outline_width)
