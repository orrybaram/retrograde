extends CollisionShape2D

var planet: Planet = null
var gravity_field: Area2D = null

func _ready() -> void:
	# This CollisionShape2D is a child of GravityField (Area2D), which is a child of Planet
	planet = NodeUtils.find_parent_of_type(self, Planet)
	gravity_field = get_parent() as Area2D
	
	_update_collision_radius()
	
	
func _update_collision_radius() -> void:
	if planet and shape is CircleShape2D:
		# Duplicate the shape to avoid modifying the shared SubResource
		var new_shape = shape.duplicate()
		if new_shape is CircleShape2D:
			new_shape.radius = planet.radius * planet.gravity_radius_multiplier
			shape = new_shape

func _physics_process(_dt: float) -> void:
	if not planet or not gravity_field:
		return
	
	# Apply gravity to all ships in the gravity field
	var overlapping_bodies = gravity_field.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body is Ship:
			#print("[%s] Ship detected in Area2D gravity field" % planet.planet_name)
			_apply_gravity_to_ship(body)

func _apply_gravity_to_ship(ship: Ship) -> void:
	var dist = planet.global_position.distance_to(ship.global_position)
	var max_gravity_radius = planet.radius * planet.gravity_radius_multiplier
	
	# Only apply gravity if ship is within the gravity radius
	if dist > max_gravity_radius:
		return


	var gravity_strength = _get_gravity_strength()
	var dir = planet.global_position.direction_to(ship.global_position)
	var force_mag = gravity_strength / max(dist * dist, 1.0)
	
	ship.apply_force(-dir * force_mag)

func _get_gravity_strength() -> float:
	return planet.mass * planet.gravitational_constant
