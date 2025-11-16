extends CollisionShape2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# This CollisionShape2D is a child of GravityField, which is a child of Planet
	var planet = NodeUtils.find_parent_of_type(self, Planet)
	
	if planet and shape is CircleShape2D:
		shape.radius = planet.radius * 20.0
		
		
