extends ShipState
class_name HarvestingState

## Handles velocity locking behavior when the ship is harvesting a resource node.

var locked_resource_node: ScrapNode = null
var velocity_tween_start: Vector2 = Vector2.ZERO
var velocity_tween_time: float = 0.0
var velocity_tween_duration: float = 2.0
var last_target_velocity: Vector2 = Vector2.ZERO
var camera_zoom_in = Vector2(1.5, 1.5)

func enter() -> void:
	super.enter()
	
	if not is_ship_valid():
		return
	
	ship.camera.zoom_camera_in(camera_zoom_in)
	
	# Use the same logic as IndicatorManager to find which resource to lock to
	# First, try to get the resource that IndicatorManager is currently highlighting
	var indicator_manager = ship.get_tree().get_first_node_in_group("indicator_manager") as IndicatorManager
	var target_resource: ScrapNode = null
	
	if indicator_manager and indicator_manager.current_target:
		var current_target = indicator_manager.current_target
		if current_target is ResourceIndicatorTarget:
			var resource_target = current_target as ResourceIndicatorTarget
			var resource = resource_target.resource_node
			# Only lock if this resource is being harvested
			if resource and is_instance_valid(resource) and resource.is_harvesting():
				target_resource = resource
	
	if target_resource and is_instance_valid(target_resource):
		locked_resource_node = target_resource
		# Initialize velocity tween from current ship velocity
		if is_ship_valid():
			velocity_tween_start = ship.linear_velocity
			velocity_tween_time = 0.0
			last_target_velocity = locked_resource_node.get_orbital_velocity()
	else:
		# No resource being harvested, go back to flying
		_exit_to_flying()

func exit() -> void:
	super.exit()
	locked_resource_node = null
	velocity_tween_time = 0.0
	velocity_tween_start = Vector2.ZERO
	last_target_velocity = Vector2.ZERO
	
	ship.camera.zoom_camera_out()

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
	
	# Update velocity tween time
	velocity_tween_time += delta
	
	# Reset camera shake
	if ship.camera:
		ship.camera_shake_time = 0.0
		ship.damage_shake_time = 0.0
		ship.damage_shake_current_intensity = 0.0
		if ship.camera.offset != ship.camera_base_offset:
			ship.camera.offset = ship.camera.offset.lerp(ship.camera_base_offset, delta * 5.0)

func integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not is_ship_valid() or not locked_resource_node or not is_instance_valid(locked_resource_node):
		return
	
	# Calculate resource node's velocity
	var resource_velocity = _get_resource_velocity()
	
	# Smoothly tween from start velocity to target velocity over 2 seconds
	var tween_progress = min(velocity_tween_time / velocity_tween_duration, 1.0)
	var new_velocity = velocity_tween_start.lerp(resource_velocity, tween_progress)
	
	state.linear_velocity = new_velocity
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
