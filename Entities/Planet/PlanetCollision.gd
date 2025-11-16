extends CollisionShape2D

func _ready() -> void:
	# This CollisionShape2D is a direct child of Planet
	var planet = get_parent() as Planet
	var planet_radius: float = 160.0  # Default fallback
	
	if planet:
		planet_radius = planet.radius
	
	if shape is CircleShape2D:
		# Duplicate the shape to avoid modifying the shared SubResource
		var new_shape = shape.duplicate()
		if new_shape is CircleShape2D:
			new_shape.radius = planet_radius
			shape = new_shape
