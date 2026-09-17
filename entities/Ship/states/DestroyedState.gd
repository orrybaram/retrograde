extends ShipState
class_name DestroyedState

## Handles ship destruction and explosion.
## This state is entered when the ship's hull strength reaches zero.

func enter() -> void:
	super.enter()
	
	if not is_ship_valid():
		return
	
	# Stop all particles
	if ship.thruster_particles:
		ship.thruster_particles.emitting = false
	if ship.boost_particles:
		ship.boost_particles.emitting = false
	if ship.side_thruster_particles:
		ship.side_thruster_particles.emitting = false
	
	_create_explosion()

	# Hide ship visual (the explosion has already copied it into debris)
	if ship.ship_polygon:
		ship.ship_polygon.visible = false
	
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
	var world := ship.get_parent()
	if not world:
		return
	# Lives in the world, not on the ship, so hiding/resetting the ship doesn't touch it
	var explosion := ShipExplosion.new()
	world.add_child(explosion)
	explosion.start(ship.ship_polygon, ship.linear_velocity, ship.camera, ship.camera_base_offset)
