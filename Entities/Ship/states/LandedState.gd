extends ShipState
class_name LandedState

## Handles planet locking behavior when the ship is landed on a planet.

var locked_planet: Planet = null
var locked_offset_from_planet: Vector2 = Vector2.ZERO

func enter() -> void:
	super.enter()
	
	if not is_ship_valid():
		return
	
	# Find closest planet to lock to
	var planets = ship.get_tree().get_nodes_in_group("planets")
	if planets.is_empty():
		# No planets, go back to flying
		_exit_to_flying()
		return
	
	var closest_planet: Planet = null
	var closest_distance: float = INF
	var ship_pos = ship.global_position
	
	for node in planets:
		if not is_instance_valid(node):
			continue
		var planet = node as Planet
		if not planet:
			continue
		
		var dist = ship_pos.distance_to(planet.global_position)
		if dist < closest_distance:
			closest_distance = dist
			closest_planet = planet
	
	if closest_planet and is_instance_valid(closest_planet):
		locked_planet = closest_planet
		locked_offset_from_planet = Vector2.ZERO  # Will be calculated on first frame

func exit() -> void:
	super.exit()
	locked_planet = null
	locked_offset_from_planet = Vector2.ZERO

func physics_process(delta: float) -> void:
	if not is_ship_valid():
		return
	
	# Sample input to check if player wants to take off
	ship.want_thrust = Input.is_action_pressed("thrust")
	ship.want_reverse_thrust = Input.is_action_pressed("reverse_thrust")
	
	# Release lock if thrusting - transition back to FlyingState
	if ship.want_thrust or ship.want_reverse_thrust:
		_exit_to_flying()
		return
	
	# Stop all particles when landed
	if ship.thruster_particles:
		ship.thruster_particles.emitting = false
	if ship.boost_particles:
		ship.boost_particles.emitting = false
	if ship.side_thruster_particles:
		ship.side_thruster_particles.emitting = false
	
	# Reset camera shake
	if ship.camera:
		ship.camera_shake_time = 0.0
		if ship.camera.offset != ship.camera_base_offset:
			ship.camera.offset = ship.camera.offset.lerp(ship.camera_base_offset, delta * 5.0)
	
	# Check if planet is still valid and close enough
	if not locked_planet or not is_instance_valid(locked_planet):
		_exit_to_flying()
		return
	
	var distance_to_planet = ship.global_position.distance_to(locked_planet.global_position)
	var distance_to_surface = distance_to_planet - locked_planet.radius
	
	# If too far from surface, unlock
	if distance_to_surface > ship.landing_lock_distance:
		_exit_to_flying()
		return

func integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not is_ship_valid() or not locked_planet or not is_instance_valid(locked_planet):
		return
	
	var planet_pos = locked_planet.global_position
	var planet_vel = locked_planet.linear_velocity
	
	# If we just locked, calculate the offset from current state position
	if locked_offset_from_planet == Vector2.ZERO:
		locked_offset_from_planet = state.transform.origin - planet_pos
	
	# Maintain the offset and update position to follow planet
	var desired_pos = planet_pos + locked_offset_from_planet
	
	# Set position and velocity to match planet
	state.transform.origin = desired_pos
	state.linear_velocity = planet_vel
	state.angular_velocity = 0.0

func _exit_to_flying() -> void:
	var state_machine = ship.get_node_or_null("StateMachine") as StateMachine
	if state_machine and state_machine.has_state("FlyingState"):
		state_machine.change_state("FlyingState")
