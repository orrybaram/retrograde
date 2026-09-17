extends ShipState
class_name StrandedState

## Handles the ship when fuel is depleted.
## The ship drifts without control until the player confirms the robot's offer to
## abandon it (or, inside a station's tractor beam, to call for a tow). Once abandoned,
## the hidden ship rides along with the DerelictShip left in its place so the camera
## stays on it.

var _requested: bool = false
var _in_beam: bool = false
var _derelict: DerelictShip = null

func enter() -> void:
	super.enter()

	if not is_ship_valid():
		return

	_requested = false
	_derelict = null
	_in_beam = _check_beam()

	# Stop all particles
	if ship.thruster_particles:
		ship.thruster_particles.emitting = false
	if ship.boost_particles:
		ship.boost_particles.emitting = false
	if ship.side_thruster_particles:
		ship.side_thruster_particles.emitting = false

	RobotRadio.confirmed.connect(_on_radio_confirmed)
	_offer_rescue()

func exit() -> void:
	super.exit()
	_requested = false
	_derelict = null
	if RobotRadio.confirmed.is_connected(_on_radio_confirmed):
		RobotRadio.confirmed.disconnect(_on_radio_confirmed)
	# Refueled some other way: withdraw an offer nobody took
	if RobotRadio.is_active() and RobotRadio.queue.current.id in [RobotRadio.MSG_OUT_OF_FUEL.id, RobotRadio.MSG_OUT_OF_FUEL_BEAM.id]:
		RobotRadio.silence()

## Take over the ship's place with `derelict`: hide the hull and follow it.
func abandon_to(derelict: DerelictShip) -> void:
	_derelict = derelict
	if ship.ship_polygon:
		ship.ship_polygon.visible = false

func _check_beam() -> bool:
	var main = ship.get_tree().get_first_node_in_group("main")
	return main != null and main.has_method("is_within_tractor_beam") and main.is_within_tractor_beam()

## The robot radios the offer that fits: a free tow inside a tractor beam, otherwise
## abandoning ship. Drifting across the beam's edge swaps one call for the other.
func _offer_rescue() -> void:
	EventBus.action_message_changed.emit("")
	var offer := RobotRadio.MSG_OUT_OF_FUEL_BEAM if _in_beam else RobotRadio.MSG_OUT_OF_FUEL
	var stale := RobotRadio.MSG_OUT_OF_FUEL if _in_beam else RobotRadio.MSG_OUT_OF_FUEL_BEAM
	if RobotRadio.is_active() and RobotRadio.queue.current.id == stale.id:
		RobotRadio.silence()
	RobotRadio.request(offer)

func _on_radio_confirmed(id: StringName) -> void:
	if _requested or not (id == RobotRadio.MSG_OUT_OF_FUEL.id or id == RobotRadio.MSG_OUT_OF_FUEL_BEAM.id):
		return
	_requested = true
	EventBus.abandon_ship_requested.emit()

func physics_process(delta: float) -> void:
	if not is_ship_valid():
		return

	# Update camera shake (ship is still drifting)
	_update_camera_shake(delta)

	if _requested:
		return
	# Drifting into or out of a tractor beam changes what the robot offers
	var in_beam := _check_beam()
	if in_beam != _in_beam:
		_in_beam = in_beam
		_offer_rescue()

func integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# No thrust control — the ship just drifts, or rides with its derelict once abandoned
	if _derelict and is_instance_valid(_derelict):
		state.transform = Transform2D(_derelict.rotation, _derelict.global_position)
		state.linear_velocity = _derelict.drift
		state.angular_velocity = 0.0

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
