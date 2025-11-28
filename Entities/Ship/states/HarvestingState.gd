extends ShipState
class_name HarvestingState

## Handles velocity locking behavior when the ship is harvesting a resource node.

var locked_resource_node: ResourceNode = null

func enter() -> void:
	super.enter()
	
	if not is_ship_valid():
		return
	
	# Find closest ResourceNode that is being harvested
	var resource_nodes = ship.get_tree().get_nodes_in_group("resource_nodes")
	if resource_nodes.is_empty():
		# No resource nodes, go back to flying
		_exit_to_flying()
		return
	
	var closest_resource: ResourceNode = null
	var closest_distance: float = INF
	var ship_pos = ship.global_position
	
	for node in resource_nodes:
		if not is_instance_valid(node):
			continue
		var resource = node as ResourceNode
		if not resource:
			continue
		
		# Only lock to resources that are currently being harvested
		if not resource.is_harvesting():
			continue
		
		var dist = ship_pos.distance_to(resource.global_position)
		if dist < closest_distance:
			closest_distance = dist
			closest_resource = resource
	
	if closest_resource and is_instance_valid(closest_resource):
		locked_resource_node = closest_resource
	else:
		# No resource being harvested, go back to flying
		_exit_to_flying()

func exit() -> void:
	super.exit()
	locked_resource_node = null

func physics_process(delta: float) -> void:
	if not is_ship_valid():
		return
	
	# Sample input to check if player wants to move
	ship.want_thrust = Input.is_action_pressed("thrust")
	ship.want_reverse_thrust = Input.is_action_pressed("reverse_thrust")
	
	# Release lock if thrusting - transition back to FlyingState
	if ship.want_thrust or ship.want_reverse_thrust:
		_exit_to_flying()
		return
	
	# Check if resource node is still valid and being harvested
	if not locked_resource_node or not is_instance_valid(locked_resource_node):
		_exit_to_flying()
		return
	
	if not locked_resource_node.is_harvesting():
		_exit_to_flying()
		return
	
	# Reset camera shake
	if ship.camera:
		ship.camera_shake_time = 0.0
		if ship.camera.offset != ship.camera_base_offset:
			ship.camera.offset = ship.camera.offset.lerp(ship.camera_base_offset, delta * 5.0)

func integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not is_ship_valid() or not locked_resource_node or not is_instance_valid(locked_resource_node):
		return
	
	# Calculate resource node's velocity
	var resource_velocity = _get_resource_velocity()
	
	# Lock ship velocity to resource node velocity
	state.linear_velocity = resource_velocity
	state.angular_velocity = 0.0

func _get_resource_velocity() -> Vector2:
	if not locked_resource_node or not is_instance_valid(locked_resource_node):
		return Vector2.ZERO
	
	# Get orbital velocity from resource node
	return locked_resource_node.get_orbital_velocity()

func _exit_to_flying() -> void:
	var state_machine = ship.get_node_or_null("StateMachine") as StateMachine
	if state_machine and state_machine.has_state("FlyingState"):
		state_machine.change_state("FlyingState")

