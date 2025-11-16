extends RigidBody2D
class_name Planet
 
@export var radius: float = 160.0
@export var gravitational_constant: float = 4.0  # G constant for scaling
@export var color: Color = Color(0.15, 0.6, 0.9) : set = _set_color
 
@onready var gravity_field: Area2D = $"GravityField"

func _set_color(c: Color) -> void:
	color = c
	# Update the visual if it exists
	var visual = get_node_or_null("Circle") as PlanetVisual
	if visual:
		visual.base_color = c

func _get_gravity_strength() -> float:
	return mass * gravitational_constant

func _ready() -> void:
	add_to_group("planets")
	# Set initial color on visual
	var visual = get_node_or_null("Circle") as PlanetVisual
	if visual:
		visual.base_color = color

func _physics_process(_dt: float) -> void:
	for body in gravity_field.get_overlapping_bodies():
		if body is Ship:
			var gravity_strength = _get_gravity_strength()
			var dir = global_position.direction_to(body.global_position)
			var dist = global_position.distance_to(body.global_position)
			var force_mag = gravity_strength / max(dist * dist, 1.0)

			body.apply_force(-dir * force_mag)
