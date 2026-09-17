extends ShipState
class_name DestroyedState

## Handles ship destruction and explosion.
## This state is entered when the ship's hull strength reaches zero.

func enter() -> void:
	super.enter()
	
	if not is_ship_valid():
		return
	
	# Hide ship visual
	if ship.ship_polygon:
		ship.ship_polygon.visible = false
	
	# Stop all particles
	if ship.thruster_particles:
		ship.thruster_particles.emitting = false
	if ship.boost_particles:
		ship.boost_particles.emitting = false
	if ship.side_thruster_particles:
		ship.side_thruster_particles.emitting = false
	
	# Create explosion particles
	_create_explosion()
	
	# Disable ship controls
	ship.set_process(false)
	ship.set_physics_process(false)

func physics_process(_delta: float) -> void:
	# Destroyed state doesn't process input or movement
	pass

func integrate_forces(_state: PhysicsDirectBodyState2D) -> void:
	# Destroyed state doesn't modify physics
	pass

func _create_explosion() -> void:
	if not is_ship_valid() or not ship.boost_particles:
		return
	
	# Create a simple explosion using existing particle system
	# We'll use the boost particles for explosion effect
	var material = ship.boost_particles.process_material as ParticleProcessMaterial
	if material:
		# Make explosion particles go in all directions
		material.direction = Vector3(0, 0, 0)
		material.spread = 360.0
		material.initial_velocity_min = 30.0
		material.initial_velocity_max = 100.0
		material.scale_min = 2.0
		material.scale_max = 8.0
		material.color = Color(1.0, 0.627, 0.2, 1.0)  # Orange/red explosion
	
	ship.boost_particles.amount = 200
	ship.boost_particles.lifetime = 1
	ship.boost_particles.emitting = true
	ship.boost_particles.one_shot = true
	
	# Also create explosion at ship position
	ship.boost_particles.position = Vector2.ZERO
	ship.boost_particles.restart()
