extends ShipState
class_name FlyingState

## Handles normal ship movement and controls.
## This is the default state when the ship is flying freely.

# Dockable is an interface - we check for methods rather than casting

var ALIGNMENT_ANGLE_THRESHOLD_DEGREES: float = 30.0
var DOCK_MESSAGE_COOLDOWN: float = 2.0  # Seconds to suppress dock message after entering state
var _state_enter_time: float = 0.0

func enter() -> void:
	super.enter()
	_state_enter_time = Time.get_ticks_msec() / 1000.0

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
	
	# Check for dockable entities and handle manual docking
	_check_dockable_proximity()
	_attempt_dock()

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
	
	var shake_offset = Vector2.ZERO
	
	# Update damage shake (decay over time)
	if ship.damage_shake_time > 0.0:
		ship.damage_shake_time -= dt
		ship.damage_shake_time = max(0.0, ship.damage_shake_time)
		
		# Calculate damage shake intensity (decay as time remaining decreases)
		# Use current intensity (set by damage or explosion) and appropriate duration
		var shake_duration = ship.damage_shake_duration
		if ship.damage_shake_current_intensity >= ship.explosion_shake_intensity * 0.9:
			# This is an explosion shake
			shake_duration = ship.explosion_shake_duration
		var damage_shake_progress = ship.damage_shake_time / shake_duration
		var current_damage_intensity = ship.damage_shake_current_intensity * damage_shake_progress
		
		# Damage shake uses faster oscillation for impact feel
		var damage_shake_phase = (shake_duration - ship.damage_shake_time) * 30.0
		shake_offset += Vector2(
			sin(damage_shake_phase * 2.1) * current_damage_intensity,
			cos(damage_shake_phase * 1.9) * current_damage_intensity
		)
	
	# Add boost shake on top of damage shake
	if ship.want_boost and ship.want_thrust:
		# Apply camera shake during boost
		ship.camera_shake_time += dt * ship.camera_shake_speed
		shake_offset += Vector2(
			sin(ship.camera_shake_time * 1.3) * ship.camera_shake_intensity,
			cos(ship.camera_shake_time * 1.7) * ship.camera_shake_intensity
		)
	else:
		# Reset boost shake time when not boosting
		ship.camera_shake_time = 0.0
	
	# Apply combined shake offset
	if shake_offset != Vector2.ZERO:
		ship.camera.offset = ship.camera_base_offset + shake_offset
	elif ship.camera.offset != ship.camera_base_offset:
		# Smoothly return to base position when no shake
		ship.camera.offset = ship.camera.offset.lerp(ship.camera_base_offset, dt * 5.0)

var _nearby_dockable: Node2D = null

func _check_dockable_proximity() -> void:
	if not is_ship_valid():
		_nearby_dockable = null
		EventBus.action_message_changed.emit("")
		return
	
	# Suppress dock message during cooldown (after taking off)
	var current_time = Time.get_ticks_msec() / 1000.0
	var in_cooldown = (current_time - _state_enter_time) < DOCK_MESSAGE_COOLDOWN
	
	var ship_pos = ship.global_position
	
	# Find all dockable entities
	var dockables = ship.get_tree().get_nodes_in_group("dockable")
	if dockables.is_empty():
		_nearby_dockable = null
		# Only clear docking message if harvest isn't available (harvest has priority)
		if not EventBus.is_harvest_available():
			EventBus.action_message_changed.emit("")
		return
	
	var closest_dockable: Node2D = null
	var closest_distance: float = INF
	
	for node in dockables:
		if not is_instance_valid(node):
			continue
		if not (node is Node2D):
			continue
		
		# Check if node has dockable methods
		var dockable_node = node as Node2D
		if not dockable_node.has_method("get_dock_position") or not dockable_node.has_method("get_dock_distance"):
			continue
		
		var dock_pos = dockable_node.get_dock_position()
		var dist = ship_pos.distance_to(dock_pos)
		var max_dist = dockable_node.get_dock_distance()
		
		if dist < max_dist and dist < closest_distance:
			closest_distance = dist
			closest_dockable = dockable_node
	
	# Update nearby dockable and show/hide message
	_nearby_dockable = closest_dockable
	
	if closest_dockable:
		# Check if ship is moving slowly enough relative to dockable
		var dockable_velocity = Vector2.ZERO
		if closest_dockable.has_method("get_dock_velocity"):
			dockable_velocity = closest_dockable.get_dock_velocity()
		var relative_velocity = ship.linear_velocity - dockable_velocity
		var is_slow_enough = relative_velocity.length() < 50.0  # Threshold for docking speed
		
		# Check if ship rotation is aligned with dock (within ±10 degrees)
		var dock_rotation = 0.0
		if closest_dockable.has_method("get_dock_rotation"):
			dock_rotation = closest_dockable.get_dock_rotation()
		else:
			dock_rotation = closest_dockable.global_rotation
		
		var target_rotation = dock_rotation + PI / -2.0  # Perpendicular (90 degrees offset)
		var ship_rotation = ship.rotation
		var angle_diff = abs(wrapf(ship_rotation - target_rotation, -PI, PI))
		var angle_threshold = deg_to_rad(ALIGNMENT_ANGLE_THRESHOLD_DEGREES)
		var is_aligned = angle_diff <= angle_threshold
		
		if is_slow_enough and is_aligned and not in_cooldown:
			# Show docking prompt (only if harvest isn't available)
			if not EventBus.is_harvest_available():
				var dock_key = InputUtils.get_action_key_name("action")
				EventBus.action_message_changed.emit('Press "%s" to dock' % [dock_key])
		else:
			# Moving too fast, not aligned, or in cooldown - clear message
			if not EventBus.is_harvest_available():
				EventBus.action_message_changed.emit("")
	else:
		# No dockable nearby, clear message (unless harvest is available)
		if not EventBus.is_harvest_available():
			EventBus.action_message_changed.emit("")

func _attempt_dock() -> void:
	if not is_ship_valid() or not _nearby_dockable or not is_instance_valid(_nearby_dockable):
		return
	
	# Don't allow docking during cooldown (after taking off)
	var current_time = Time.get_ticks_msec() / 1000.0
	if (current_time - _state_enter_time) < DOCK_MESSAGE_COOLDOWN:
		return
	
	# Check if action key is pressed
	if not Input.is_action_just_pressed("action"):
		return
	
	# Validate ship is close enough
	var ship_pos = ship.global_position
	var dock_pos = _nearby_dockable.get_dock_position()
	var dist = ship_pos.distance_to(dock_pos)
	
	if dist > _nearby_dockable.get_dock_distance():
		return
	
	# Validate ship is moving slowly enough relative to dockable
	var dockable_velocity = Vector2.ZERO
	if _nearby_dockable.has_method("get_dock_velocity"):
		dockable_velocity = _nearby_dockable.get_dock_velocity()
	var relative_velocity = ship.linear_velocity - dockable_velocity
	if relative_velocity.length() >= 50.0:
		return
	
	# Validate ship rotation is aligned with dock (within ±10 degrees)
	var dock_rotation = 0.0
	if _nearby_dockable.has_method("get_dock_rotation"):
		dock_rotation = _nearby_dockable.get_dock_rotation()
	else:
		dock_rotation = _nearby_dockable.global_rotation
	
	# Calculate target rotation (perpendicular to dock surface)
	var target_rotation = dock_rotation + PI / -2.0  # Perpendicular (90 degrees offset)
	
	# Get current ship rotation and calculate angle difference
	var ship_rotation = ship.rotation
	var angle_diff = abs(wrapf(ship_rotation - target_rotation, -PI, PI))
	
	var angle_threshold = deg_to_rad(ALIGNMENT_ANGLE_THRESHOLD_DEGREES)
	
	if angle_diff > angle_threshold:
		return  # Ship is not aligned correctly
	
	# Transition to LandedState with the dockable entity
	# Store dockable reference on ship for LandedState to pick up
	ship.set_meta("pending_dockable", _nearby_dockable)
	
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
