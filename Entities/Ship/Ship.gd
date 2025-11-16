extends RigidBody2D
class_name Ship

@export var thrust_power: float = 500.0
@export var turn_speed: float = 5
@export var fuel_consumption_rate: float = 1.0  # Fuel consumed per second when thrusting
@export var boost_power_multiplier: float = 2.0  # Multiplier for boost thrust power
@export var boost_fuel_multiplier: float = 3.0  # Multiplier for boost fuel consumption

var want_turn_left := false
var want_turn_right := false
var want_thrust := false
var want_reverse_thrust := false
var want_boost := false
var gs: GameState = null

@onready var thruster_particles: GPUParticles2D = $"ThrusterParticles"
@onready var boost_particles: GPUParticles2D = $"BoostParticles"
@onready var side_thruster_particles: GPUParticles2D = $"SideThrusterParticles"

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	can_sleep = false  # keep body awake while testing input; turn back on later if you like
	# Try to get GameState, with fallback
	gs = get_tree().get_first_node_in_group("game_state")
	
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
	
	# If any input, ensure the body is awake
	if want_turn_left or want_turn_right or want_thrust or want_reverse_thrust or want_boost:
		sleeping = false
	
	# Update particle systems
	_update_particles()

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Use cached inputs to modify physics state
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
	
