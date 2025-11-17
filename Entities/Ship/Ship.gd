extends RigidBody2D
class_name Ship

@export var thrust_power: float = 500.0
@export var turn_speed: float = 5
@export var fuel_consumption_rate: float = 1.0  # Fuel consumed per second when thrusting
@export var boost_power_multiplier: float = 2.0  # Multiplier for boost thrust power
@export var boost_fuel_multiplier: float = 3.0  # Multiplier for boost fuel consumption

@export var max_hull: float = 100.0
@export var crash_damage_multiplier: float = 0.5  # Damage per unit of collision velocity

var want_turn_left := false
var want_turn_right := false
var want_thrust := false
var want_reverse_thrust := false
var want_boost := false
var gs: GameState = null
var hull_strength: float = 100.0
var is_destroyed: bool = false
var last_damage_time: float = 0.0
var damage_cooldown: float = 0.1  # Minimum time between damage applications (seconds)

# Landing lock system
var is_locked_to_planet: bool = false
var locked_planet: Planet = null
var landing_lock_distance: float = 10.0  # Distance threshold for landing lock (pixels above surface)
var locked_offset_from_planet: Vector2 = Vector2.ZERO  # Offset from planet center when locked

@onready var thruster_particles: GPUParticles2D = $"ThrusterParticles"
@onready var boost_particles: GPUParticles2D = $"BoostParticles"
@onready var side_thruster_particles: GPUParticles2D = $"SideThrusterParticles"
@onready var ship_polygon: Polygon2D = $"Polygon2D"
@onready var camera: Camera2D = $"Camera2D"

@export var camera_shake_intensity: float = 1.2  # How much the camera shakes
@export var camera_shake_speed: float = 25.0  # How fast the shake oscillates

var camera_shake_time: float = 0.0
var camera_base_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("ship")
	contact_monitor = true
	max_contacts_reported = 4
	can_sleep = false  # keep body awake while testing input; turn back on later if you like
	# Try to get GameState, with fallback
	gs = get_tree().get_first_node_in_group("game_state")
	
	# Initialize hull
	hull_strength = max_hull
	
	# Store initial camera offset for shake calculations
	if camera:
		camera_base_offset = camera.offset
	
	# Duplicate particle materials so we can modify them at runtime
	if thruster_particles and thruster_particles.process_material:
		thruster_particles.process_material = thruster_particles.process_material.duplicate()
	if boost_particles and boost_particles.process_material:
		boost_particles.process_material = boost_particles.process_material.duplicate()
	if side_thruster_particles and side_thruster_particles.process_material:
		side_thruster_particles.process_material = side_thruster_particles.process_material.duplicate()

func _physics_process(_dt: float) -> void:
	# Sample input here (physics rate, thread-safe for our purposes)
	want_turn_left  = Input.is_action_pressed("turn_left")
	want_turn_right = Input.is_action_pressed("turn_right")
	want_thrust = Input.is_action_pressed("thrust")
	want_reverse_thrust = Input.is_action_pressed("reverse_thrust")
	want_boost = Input.is_action_pressed("boost")
	
	# Release lock if thrusting
	if (want_thrust or want_reverse_thrust) and is_locked_to_planet:
		is_locked_to_planet = false
		locked_planet = null
		locked_offset_from_planet = Vector2.ZERO
	
	# If any input, ensure the body is awake
	if want_turn_left or want_turn_right or want_thrust or want_reverse_thrust or want_boost:
		sleeping = false
	
	# Update particle systems
	_update_particles()
	
	# Update camera shake
	_update_camera_shake(_dt)
	
	# Check for landing lock
	_check_landing_lock()

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Handle landing lock - keep ship position and velocity locked to planet
	if is_locked_to_planet and locked_planet and is_instance_valid(locked_planet):
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
		return
	
	if not is_destroyed and state.get_contact_count() > 0:
		var current_time = Time.get_ticks_msec() / 1000.0
		
		if current_time - last_damage_time >= damage_cooldown:
			for i in state.get_contact_count():
				var collider := state.get_contact_collider_object(i)
				var collision_normal = state.get_contact_local_normal(i)
				
				if collider == null or collider == self:
					continue
				if not (collider is RigidBody2D):
					continue

				var ship_speed = state.get_contact_local_velocity_at_position(i)
				
				var collider_speed = collider.linear_velocity
				var relative_velocity = ship_speed - collider_speed;
				var speed_along_normal = relative_velocity.dot(collision_normal)
				var impact_speed: int = abs(speed_along_normal);
				
				var damage_threshold := 80
				if impact_speed > damage_threshold:
					var damage := (impact_speed - damage_threshold) * crash_damage_multiplier
					take_damage(damage)
					last_damage_time = current_time
					break

	
	# Use cached inputs to modify physics state
	if is_destroyed:
		return
		
	if want_turn_left:
		state.angular_velocity = -turn_speed
	elif want_turn_right:
		state.angular_velocity = turn_speed
	else:
		state.angular_velocity = 0.0  # Stop rotation when no input
		pass

	if want_thrust and gs:
		# Calculate fuel consumption (boost consumes more)
		var fuel_rate = fuel_consumption_rate
		if want_boost:
			fuel_rate *= boost_fuel_multiplier
		
		# Try to consume fuel - only thrust if we have fuel
		if gs.consume_fuel(fuel_rate * state.step):
			# Calculate thrust power (boost adds extra power)
			var power = thrust_power
			if want_boost:
				power *= boost_power_multiplier
			
			var force = Vector2.RIGHT.rotated(rotation) * power
			state.apply_central_force(force)
	if want_reverse_thrust and gs:
		# Calculate fuel consumption (boost consumes more)
		var fuel_rate = fuel_consumption_rate
		if want_boost:
			fuel_rate *= boost_fuel_multiplier
		
		# Try to consume fuel - only thrust if we have fuel
		if gs.consume_fuel(fuel_rate * state.step):
			# Calculate thrust power (boost adds extra power)
			var power = thrust_power
			if want_boost:
				power *= boost_power_multiplier
			
			var force = Vector2.LEFT.rotated(rotation) * power
			state.apply_central_force(force)

func _update_particles() -> void:
	if not thruster_particles or not boost_particles:
		return
	
	# Determine if we're thrusting (forward or reverse)
	var is_thrusting = (want_thrust or want_reverse_thrust) and gs and gs.fuel > 0.0
	
	if is_thrusting:
		# Update particle direction based on thrust direction
		var material_normal = thruster_particles.process_material as ParticleProcessMaterial
		var material_boost = boost_particles.process_material as ParticleProcessMaterial
		
		if material_normal and material_boost:
			# Ship points RIGHT (0°), so back is LEFT
			# For forward thrust, particles go LEFT (opposite ship direction)
			# For reverse thrust, particles go RIGHT (same as ship direction)
			var local_direction = Vector2.LEFT if want_thrust else Vector2.RIGHT
			var dir_vec3 = Vector3(local_direction.x, local_direction.y, 0)
			material_normal.direction = dir_vec3
			material_boost.direction = dir_vec3
		
		# Switch between normal and boost particles
		if want_boost:
			thruster_particles.emitting = false
			boost_particles.emitting = true
		else:
			thruster_particles.emitting = true
			boost_particles.emitting = false
	else:
		# Stop emitting when not thrusting
		thruster_particles.emitting = false
		boost_particles.emitting = false
	
	# Update side thruster particles for turning
	# Ship points RIGHT (0°), so 90° left = UP (90°), 90° right = DOWN (270° or -90°)
	if side_thruster_particles:
		var is_turning = want_turn_left or want_turn_right
		side_thruster_particles.emitting = is_turning
		
		if is_turning:
			var material = side_thruster_particles.process_material as ParticleProcessMaterial
			if material:
				# Ship points RIGHT (0°) in local space
				# In 2D: Y increases downward
				# Ship polygon: Y=-7 (left side), Y=7 (right side)
				# Physics: To turn left (CCW), need thrust from RIGHT side (Y=7)
				#         To turn right (CW), need thrust from LEFT side (Y=-7)
				if want_turn_left:
					# Position on RIGHT side of ship (Y=7) - particles go 90° left of ship (UP)
					side_thruster_particles.position = Vector2(0, -7)
					material.direction = Vector3(0, 1, 0)
				elif want_turn_right:
					# Position on LEFT side of ship (Y=-7) - particles go 90° right of ship (DOWN)
					side_thruster_particles.position = Vector2(0, 7)
					material.direction = Vector3(0, -1, 0)

func _check_landing_lock() -> void:
	# Don't lock if already locked or if thrusting
	if is_locked_to_planet or want_thrust or want_reverse_thrust:
		return
	
	# Find closest planet
	var planets = get_tree().get_nodes_in_group("planets")
	if planets.is_empty():
		return
	
	var closest_planet: Planet = null
	var closest_distance: float = INF
	var ship_pos = global_position
	
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
	
	# Check if ship is close enough to surface to lock
	if closest_planet and is_instance_valid(closest_planet):
		var distance_to_surface = closest_distance - closest_planet.radius
		if distance_to_surface <= landing_lock_distance and distance_to_surface >= 0:
			# Also check if ship is moving slowly relative to planet
			var relative_velocity = linear_velocity - closest_planet.linear_velocity
			if relative_velocity.length() < 50.0:  # Threshold for "landed" speed
				is_locked_to_planet = true
				locked_planet = closest_planet
				# Reset offset - will be calculated on first lock frame
				locked_offset_from_planet = Vector2.ZERO

func _update_camera_shake(dt: float) -> void:
	if not camera:
		return
	
	if want_boost and not is_destroyed:
		# Apply camera shake during boost
		camera_shake_time += dt * camera_shake_speed
		var shake_offset = Vector2(
			sin(camera_shake_time * 1.3) * camera_shake_intensity,
			cos(camera_shake_time * 1.7) * camera_shake_intensity
		)
		camera.offset = camera_base_offset + shake_offset
	else:
		# Smoothly return to base position when not boosting
		camera_shake_time = 0.0
		if camera.offset != camera_base_offset:
			camera.offset = camera.offset.lerp(camera_base_offset, dt * 5.0)


func take_damage(amount: float) -> void:
	if is_destroyed:
		return
	
	hull_strength -= amount
	hull_strength = max(0.0, hull_strength)
	
	if hull_strength <= 0.0 and not is_destroyed:
		explode()

func explode() -> void:
	if is_destroyed:
		return
	
	is_destroyed = true
	
	# Hide ship visual
	if ship_polygon:
		ship_polygon.visible = false
	
	# Stop all particles
	if thruster_particles:
		thruster_particles.emitting = false
	if boost_particles:
		boost_particles.emitting = false
	if side_thruster_particles:
		side_thruster_particles.emitting = false
	
	# Create explosion particles
	_create_explosion()
	
	# Disable ship controls
	set_process(false)
	set_physics_process(false)
	
	# Make ship non-interactive (optional - you might want to keep physics for debris)
	# queue_free()

func _create_explosion() -> void:
	# Create a simple explosion using existing particle system
	# We'll use the boost particles for explosion effect
	if boost_particles:
		var material = boost_particles.process_material as ParticleProcessMaterial
		if material:
			# Make explosion particles go in all directions
			material.direction = Vector3(0, 0, 0)
			material.spread = 360.0
			material.initial_velocity_min = 30.0
			material.initial_velocity_max = 100.0
			material.scale_min = 2.0
			material.scale_max = 8.0
			material.color = Color(1.0, 0.627, 0.2, 1.0)  # Orange/red explosion
		
		boost_particles.amount = 200
		boost_particles.lifetime = 1
		boost_particles.emitting = true
		boost_particles.one_shot = true
		
		# Also create explosion at ship position
		boost_particles.position = Vector2.ZERO
		boost_particles.restart()
	
