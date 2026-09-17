extends ShipState
class_name StrandedState

## Handles the ship when fuel is depleted.
## The ship drifts without control until the player confirms the robot's
## offer to send a rescue beacon.

var _beacon_deployed: bool = false

func enter() -> void:
	super.enter()

	if not is_ship_valid():
		return

	_beacon_deployed = false

	# Stop all particles
	if ship.thruster_particles:
		ship.thruster_particles.emitting = false
	if ship.boost_particles:
		ship.boost_particles.emitting = false
	if ship.side_thruster_particles:
		ship.side_thruster_particles.emitting = false

	# The robot offers a rescue beacon; confirming it deploys one
	EventBus.action_message_changed.emit("")
	RobotRadio.confirmed.connect(_on_radio_confirmed)
	RobotRadio.request(RobotRadio.MSG_OUT_OF_FUEL)

func exit() -> void:
	super.exit()
	_beacon_deployed = false
	if RobotRadio.confirmed.is_connected(_on_radio_confirmed):
		RobotRadio.confirmed.disconnect(_on_radio_confirmed)

func _on_radio_confirmed(id: StringName) -> void:
	if id == RobotRadio.MSG_OUT_OF_FUEL.id and not _beacon_deployed:
		_deploy_beacon()

func physics_process(delta: float) -> void:
	if not is_ship_valid():
		return

	# Update camera shake (ship is still drifting)
	_update_camera_shake(delta)

func integrate_forces(_state: PhysicsDirectBodyState2D) -> void:
	# No thrust control — ship just drifts
	pass

func _deploy_beacon() -> void:
	_beacon_deployed = true
	EventBus.action_message_changed.emit("")
	EventBus.rescue_beacon_deployed.emit()

func _update_camera_shake(dt: float) -> void:
	if not is_ship_valid() or not ship.camera:
		return

	# Decay any remaining damage shake
	if ship.damage_shake_time > 0.0:
		ship.damage_shake_time -= dt
		ship.damage_shake_time = max(0.0, ship.damage_shake_time)

		var shake_duration = ship.damage_shake_duration
		if ship.damage_shake_current_intensity >= ship.explosion_shake_intensity * 0.9:
			shake_duration = ship.explosion_shake_duration
		var damage_shake_progress = ship.damage_shake_time / shake_duration
		var current_damage_intensity = ship.damage_shake_current_intensity * damage_shake_progress

		var damage_shake_phase = (shake_duration - ship.damage_shake_time) * 30.0
		var shake_offset = Vector2(
			sin(damage_shake_phase * 2.1) * current_damage_intensity,
			cos(damage_shake_phase * 1.9) * current_damage_intensity
		)
		ship.camera.offset = ship.camera_base_offset + shake_offset
	elif ship.camera.offset != ship.camera_base_offset:
		ship.camera.offset = ship.camera.offset.lerp(ship.camera_base_offset, dt * 5.0)
