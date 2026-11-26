extends ShipState
class_name DestroyedState

## Handles ship destruction and explosion.
## This state is entered when the ship's hull strength reaches zero.
## The (hidden) ship body is pinned at the point of impact so its camera stays on the blast.

var _impact := Vector2.ZERO

func allows_sonar() -> bool:
	return false

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
	
	_impact = ship.global_position
	_create_explosion()
	ship.linear_velocity = Vector2.ZERO
	ship.angular_velocity = 0.0

	# Hide ship visual (the explosion has already copied it into debris)
	if ship.ship_polygon:
		ship.ship_polygon.visible = false
	
	# Disable ship controls
	ship.set_process(false)
	ship.set_physics_process(false)

func physics_process(_delta: float) -> void:
	# Destroyed state doesn't process input or movement
	pass

func integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	state.transform.origin = _impact
	state.linear_velocity = Vector2.ZERO
	state.angular_velocity = 0.0

func _create_explosion() -> void:
	var world := ship.get_parent()
	if not world:
		return
	# Lives in the world, not on the ship, so hiding/resetting the ship doesn't touch it
	var explosion := ShipExplosion.new()
	world.add_child(explosion)
	explosion.start(ship.ship_polygon, ship.linear_velocity, ship.camera, ship.camera_base_offset)
	# Part of the hold spills out and stays at the wreck
	var drops := GemData.wreck_drops(InventoryManager.get_all_items())
	if not drops.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		Gem.wreck_burst(world, ship.global_position, drops, rng)
