extends ShipState
class_name FlyingState

## Handles normal ship movement and controls.
## This is the default state when the ship is flying freely.

func enter() -> void:
	super.enter()

func physics_process(delta: float) -> void:
	if not is_ship_valid():
		return
	
	# Don't process ship input if system map is open
	if _is_system_map_open():
		ship.want_turn_left = false
		ship.want_turn_right = false
		ship.want_thrust = false
		ship.want_reverse_thrust = false
		ship.want_boost = false
		return
	
	# Sample input here (physics rate, thread-safe for our purposes)
	ship.want_turn_left = Input.is_action_pressed("turn_left")
	ship.want_turn_right = Input.is_action_pressed("turn_right")
	ship.want_thrust = Input.is_action_pressed("thrust")
	ship.want_reverse_thrust = Input.is_action_pressed("reverse_thrust")
	ship.want_boost = Input.is_action_pressed("boost")
	
	# If any input, ensure the body is awake
	if ship.want_turn_left or ship.want_turn_right or ship.want_thrust or ship.want_reverse_thrust or ship.want_boost:
		ship.sleeping = false
	
	# Update particle systems
	_update_particles()
	
	# Update camera shake
	_update_camera_shake(delta)
	
	# Check for landing lock - transition to LandedState if conditions met
	_check_landing_lock()

func integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not is_ship_valid():
		return
	
	# Handle collision damage
	if state.get_contact_count() > 0:
		var current_time = Time.get_ticks_msec() / 1000.0
		
		if current_time - ship.last_damage_time >= ship.damage_cooldown:
			for i in state.get_contact_count():
				var collider := state.get_contact_collider_object(i)
				var collision_normal = state.get_contact_local_normal(i)
				
				if collider == null or collider == ship:
					continue
				if not (collider is RigidBody2D):
					continue

				var ship_speed = state.get_contact_local_velocity_at_position(i)
				
				var collider_speed = collider.linear_velocity
				var relative_velocity = ship_speed - collider_speed
				var speed_along_normal = relative_velocity.dot(collision_normal)
				var impact_speed: int = abs(speed_along_normal)
				
				if impact_speed > ship.damage_threshold:
					var damage: float = (impact_speed - ship.damage_threshold) * ship.crash_damage_multiplier
					ship.take_damage(damage)
					ship.last_damage_time = current_time
					break
	
	# Handle movement controls
	if ship.want_turn_left:
		state.angular_velocity = -ship.turn_speed
	elif ship.want_turn_right:
		state.angular_velocity = ship.turn_speed
	else:
		state.angular_velocity = 0.0  # Stop rotation when no input

	if ship.want_thrust:
		# Calculate fuel consumption (boost consumes more)
		var fuel_rate = ship.fuel_consumption_rate
		if ship.want_boost:
			fuel_rate *= ship.boost_fuel_multiplier
		
		# Try to consume fuel - only thrust if we have fuel
		if ship.consume_fuel(fuel_rate * state.step):
			# Calculate thrust power (boost adds extra power)
			var power = ship.thrust_power
			if ship.want_boost:
				power *= ship.boost_power_multiplier
			
			var force = Vector2.RIGHT.rotated(ship.rotation) * power
			state.apply_central_force(force)
	
	if ship.want_reverse_thrust:
		# Calculate fuel consumption (boost consumes more)
		var fuel_rate = ship.fuel_consumption_rate
		if ship.want_boost:
			fuel_rate *= ship.boost_fuel_multiplier
		
		# Try to consume fuel - only thrust if we have fuel
		if ship.consume_fuel(fuel_rate * state.step):
			# Calculate thrust power (boost adds extra power)
			var power = ship.thrust_power
			if ship.want_boost:
				power *= ship.boost_power_multiplier
			
			var force = Vector2.LEFT.rotated(ship.rotation) * power
			state.apply_central_force(force)

func _update_particles() -> void:
	if not is_ship_valid() or not ship.thruster_particles or not ship.boost_particles:
		return
	
	# Determine if we're thrusting (forward or reverse)
	var is_thrusting = (ship.want_thrust or ship.want_reverse_thrust) and ship.fuel > 0.0
	
	if is_thrusting:
		# Update particle direction based on thrust direction
		var material_normal = ship.thruster_particles.process_material as ParticleProcessMaterial
		var material_boost = ship.boost_particles.process_material as ParticleProcessMaterial
		
		if material_normal and material_boost:
			# Ship points RIGHT (0°), so back is LEFT
			# For forward thrust, particles go LEFT (opposite ship direction)
			# For reverse thrust, particles go RIGHT (same as ship direction)
			var local_direction = Vector2.LEFT if ship.want_thrust else Vector2.RIGHT
			var dir_vec3 = Vector3(local_direction.x, local_direction.y, 0)
			material_normal.direction = dir_vec3
			material_boost.direction = dir_vec3
		
		# Switch between normal and boost particles
		if ship.want_boost:
			ship.thruster_particles.emitting = false
			ship.boost_particles.emitting = true
		else:
			ship.thruster_particles.emitting = true
			ship.boost_particles.emitting = false
	else:
		# Stop emitting when not thrusting
		ship.thruster_particles.emitting = false
		ship.boost_particles.emitting = false
	
	# Update side thruster particles for turning
	# Ship points RIGHT (0°), so 90° left = UP (90°), 90° right = DOWN (270° or -90°)
	if ship.side_thruster_particles:
		var is_turning = ship.want_turn_left or ship.want_turn_right
		ship.side_thruster_particles.emitting = is_turning
		
		if is_turning:
			var material = ship.side_thruster_particles.process_material as ParticleProcessMaterial
			if material:
				# Ship points RIGHT (0°) in local space
				# In 2D: Y increases downward
				# Ship polygon: Y=-7 (left side), Y=7 (right side)
				# Physics: To turn left (CCW), need thrust from RIGHT side (Y=7)
				#         To turn right (CW), need thrust from LEFT side (Y=-7)
				if ship.want_turn_left:
					# Position on RIGHT side of ship (Y=7) - particles go 90° left of ship (UP)
					ship.side_thruster_particles.position = Vector2(0, -7)
					material.direction = Vector3(0, 1, 0)
				elif ship.want_turn_right:
					# Position on LEFT side of ship (Y=-7) - particles go 90° right of ship (DOWN)
					ship.side_thruster_particles.position = Vector2(0, 7)
					material.direction = Vector3(0, -1, 0)

func _update_camera_shake(dt: float) -> void:
	if not is_ship_valid() or not ship.camera:
		return
	
	if ship.want_boost and ship.want_thrust:
		# Apply camera shake during boost
		ship.camera_shake_time += dt * ship.camera_shake_speed
		var shake_offset = Vector2(
			sin(ship.camera_shake_time * 1.3) * ship.camera_shake_intensity,
			cos(ship.camera_shake_time * 1.7) * ship.camera_shake_intensity
		)
		ship.camera.offset = ship.camera_base_offset + shake_offset
	else:
		# Smoothly return to base position when not boosting
		ship.camera_shake_time = 0.0
		if ship.camera.offset != ship.camera_base_offset:
			ship.camera.offset = ship.camera.offset.lerp(ship.camera_base_offset, dt * 5.0)

func _check_landing_lock() -> void:
	if not is_ship_valid():
		return
	
	# Don't lock if thrusting
	if ship.want_thrust or ship.want_reverse_thrust:
		return
	
	var ship_pos = ship.global_position
	
	# Check SpacePorts only
	var space_ports = ship.get_tree().get_nodes_in_group("space_ports")
	if space_ports.is_empty():
		return
	
	var closest_spaceport: SpacePort = null
	var closest_spaceport_distance: float = INF
	
	for node in space_ports:
		if not is_instance_valid(node):
			continue
		var spaceport = node as SpacePort
		if not spaceport:
			continue
		
		var pad_pos = spaceport.get_landing_pad_position()
		var dist = ship_pos.distance_to(pad_pos)
		if dist < closest_spaceport_distance:
			closest_spaceport_distance = dist
			closest_spaceport = spaceport
	
	# Check if ship is close enough to SpacePort landing pad to lock
	if closest_spaceport and is_instance_valid(closest_spaceport):
		if closest_spaceport_distance <= closest_spaceport.landing_lock_distance:
			# Also check if ship is moving slowly relative to SpacePort
			var spaceport_velocity = Vector2.ZERO
			# Get SpacePort's velocity (it moves with its parent planet)
			var spaceport_parent = closest_spaceport.get_parent()
			if spaceport_parent is RigidBody2D:
				spaceport_velocity = (spaceport_parent as RigidBody2D).linear_velocity
			
			var relative_velocity = ship.linear_velocity - spaceport_velocity
			if relative_velocity.length() < 50.0:  # Threshold for "landed" speed
				# Transition to LandedState with SpacePort
				var state_machine = ship.get_node_or_null("StateMachine") as StateMachine
				if state_machine and state_machine.has_state("LandedState"):
					state_machine.change_state("LandedState")

func _is_system_map_open() -> bool:
	if not ship or not is_instance_valid(ship):
		return false
	var tree = ship.get_tree()
	if not tree:
		return false
	var system_map = tree.get_first_node_in_group("system_map") as SystemMap
	if system_map:
		return system_map.visible
	# Fallback: search by class name
	var nodes = tree.get_nodes_in_group("system_map")
	for node in nodes:
		if node is SystemMap and node.visible:
			return true
	return false
