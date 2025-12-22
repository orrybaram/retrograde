extends CollisionShape2D

func _ready() -> void:
	# This CollisionShape2D is a direct child of Planet
	var planet = get_parent() as Planet
	var planet_radius: float = 160.0  # Default fallback
	var collision_ratio: float = 1.0  # Default to full collision
	
	if planet:
		planet_radius = planet.radius
		collision_ratio = planet.collision_radius_ratio
	
	# Calculate actual collision radius (gas giants have smaller cores)
	var collision_radius = planet_radius * collision_ratio
	
	if shape is CircleShape2D:
		# Duplicate the shape to avoid modifying the shared SubResource
		var new_shape = shape.duplicate()
		if new_shape is CircleShape2D:
			new_shape.radius = collision_radius
			shape = new_shape
