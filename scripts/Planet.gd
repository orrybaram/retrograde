extends Node2D
class_name Planet

@export var mass: float = 10000000.0
@export var radius: float = 160.0
@export var gravitational_constant: float = 4.0  # G constant for scaling

@onready var gravity_field: Area2D = $"GravityField"

func _get_gravity_strength() -> float:
	return mass * gravitational_constant

func _ready() -> void:
	add_to_group("planets")

func _physics_process(_dt: float) -> void:
	for body in gravity_field.get_overlapping_bodies():
		if body is Ship:
			var gravity_strength = _get_gravity_strength()
			var dir = global_position.direction_to(body.global_position)
			var dist = global_position.distance_to(body.global_position)
			var force_mag = gravity_strength / max(dist * dist, 1.0)

			print(force_mag)
			body.apply_central_force(-dir * force_mag)
