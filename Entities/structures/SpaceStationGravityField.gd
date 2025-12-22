extends CollisionShape2D

## GravityField collision shape for SpaceStation.
## Sets the gravity field radius based on the station's properties.

func _ready() -> void:
	# This CollisionShape2D is a child of GravityField, which is a child of SpaceStation
	# Find parent SpaceStation by traversing up the tree
	var station: SpaceStation = null
	var current = get_parent()
	while current:
		if current is SpaceStation:
			station = current as SpaceStation
			break
		current = current.get_parent()
	
	if station and shape is CircleShape2D:
		# Use a fixed radius for space stations (smaller than planets)
		var base_radius = 80.0  # Approximate station size
		shape.radius = base_radius * station.gravity_radius_multiplier

