extends ShipState
class_name ConsumedState

## The Void closed over the ship. Unlike DestroyedState there is no blast, no
## debris and no wreck to come back for — the hull simply stops being anywhere,
## and the camera holds on the dark where it was. By the time this state is
## entered the shroud is already total, so there is nothing to see it happen.

var _last_seen := Vector2.ZERO

func allows_sonar() -> bool:
	return false

func enter() -> void:
	super.enter()

	if not is_ship_valid():
		return

	for particles in [ship.thruster_particles, ship.boost_particles, ship.side_thruster_particles]:
		if particles:
			particles.emitting = false

	_last_seen = ship.global_position
	ship.linear_velocity = Vector2.ZERO
	ship.angular_velocity = 0.0

	if ship.ship_polygon:
		ship.ship_polygon.visible = false

	ship.set_process(false)
	ship.set_physics_process(false)

func physics_process(_delta: float) -> void:
	pass

func integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	state.transform.origin = _last_seen
	state.linear_velocity = Vector2.ZERO
	state.angular_velocity = 0.0
