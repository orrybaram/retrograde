extends ShipState
class_name StrandedState

## Handles the ship when fuel is depleted.
## The ship drifts without control until the player abandons it (or, inside a station's
## tractor beam, calls for a tow). Once abandoned, the hidden ship rides along with the
## DerelictShip left in its place so the camera stays on it.

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

	_show_prompt()

func exit() -> void:
	super.exit()
	_requested = false
	_derelict = null
	EventBus.action_message_changed.emit("")

## Take over the ship's place with `derelict`: hide the hull and follow it.
func abandon_to(derelict: DerelictShip) -> void:
	_derelict = derelict
	if ship.ship_polygon:
		ship.ship_polygon.visible = false

func _check_beam() -> bool:
	var main = ship.get_tree().get_first_node_in_group("main")
	return main != null and main.has_method("is_within_tractor_beam") and main.is_within_tractor_beam()

func _show_prompt() -> void:
	var action_key = InputUtils.get_action_key_name("action")
	if _in_beam:
		EventBus.action_message_changed.emit('OUT OF FUEL - Press "%s" to call the tractor beam' % [action_key])
	else:
		EventBus.action_message_changed.emit('OUT OF FUEL - Press "%s" to abandon ship' % [action_key])

func physics_process(delta: float) -> void:
	if not is_ship_valid():
		return

	# Update camera shake (ship is still drifting)
	_update_camera_shake(delta)

	if _requested:
		return
	# Drifting into or out of a tractor beam changes what the key does
	var in_beam := _check_beam()
	if in_beam != _in_beam:
		_in_beam = in_beam
		_show_prompt()
	if Input.is_action_just_pressed("action"):
		_requested = true
		EventBus.action_message_changed.emit("")
		EventBus.abandon_ship_requested.emit()

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
