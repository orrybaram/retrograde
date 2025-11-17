extends Node2D

@onready var ship := $Ship
@onready var tick := $TickTimer

func _ready() -> void:
	tick.timeout.connect(_on_tick)
	# Wait for next frame to ensure Earth is fully initialized
	await get_tree().process_frame
	_spawn_ship_on_earth()

func _spawn_ship_on_earth() -> void:
	var earth = get_node_or_null("Sun/Earth") as Planet
	if not earth:
		return
	
	# Wait for Earth's first physics frame to calculate orbital velocity
	await get_tree().physics_frame
	
	# Get Earth's global position
	var earth_global_pos = earth.global_position
	var earth_radius = earth.radius
		
	# Position ship on Earth's surface (above the center)
	var spawn_offset = Vector2(0, -earth_radius - 10)  # 50 pixels above surface
	ship.global_position = earth_global_pos + spawn_offset
	
	# Set ship's velocity to match Earth's orbital velocity (stationary relative to Earth)
	ship.linear_velocity = earth.linear_velocity

func _on_tick() -> void:
	for node in get_tree().get_nodes_in_group("resource_nodes"):
		if ship.global_position.distance_to(node.global_position) < 32 and ship.grounded:
			node.start_harvest()
		else:
			node.stop_harvest()
