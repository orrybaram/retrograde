extends CollisionShape2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# This CollisionShape2D is a child of GravityField, which is a child of Planet
	var planet = get_parent().get_parent()
	var planet_radius: float = 160.0  # Default fallback
	
	if planet:
		planet_radius = planet.radius
	
	if shape is CircleShape2D:
		shape.radius = planet_radius * 20.0
		
