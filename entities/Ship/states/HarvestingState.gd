extends ShipState
class_name HarvestingState

## Focused on one scrap from its first hit until it's exhausted or the ship leaves
## harvest range, so the camera stays zoomed across hits instead of bouncing.
## While locked, the ship's velocity eases onto the scrap's orbit. Any flight input
## releases the lock and the ship flies normally (still focused, via FlyingState's
## controls); pressing action on the scrap again re-engages it. After the final
## break the zoom lingers briefly so the burst and gem pickup read.

const LINGER_AFTER_BREAK := 0.8

var focus: ScrapNode = null
var velocity_tween_start: Vector2 = Vector2.ZERO
var velocity_tween_time: float = 0.0
var velocity_tween_duration: float = 2.0
var camera_zoom_in: Vector2 = Vector2(1.5, 1.5)
var _locked := false
var _linger := -1.0

func enter() -> void:
	super.enter()

	if not is_ship_valid():
		return
	if not _focus_alive():
		_exit_to_flying()
		return

	ship.camera.zoom_camera_in(camera_zoom_in)

	ship.damage_shake_time = ship.harvest_lockon_shake_duration
	ship.damage_shake_current_intensity = ship.harvest_lockon_shake_intensity

	_get_pulse().emitting = Input.is_action_pressed("action")

func exit() -> void:
	super.exit()
	focus = null
	_locked = false
	_linger = -1.0
	velocity_tween_time = 0.0
	velocity_tween_start = Vector2.ZERO

	ship.camera.zoom_camera_out()

	_get_pulse().emitting = false

## Called by ScrapHarvestingState each time the beam starts on a scrap.
func focus_on(scrap: ScrapNode) -> void:
	focus = scrap
	_linger = -1.0
	_locked = true
	velocity_tween_start = ship.linear_velocity
	velocity_tween_time = 0.0

func is_locked() -> bool:
	return _locked

func physics_process(delta: float) -> void:
	if not is_ship_valid():
		return
	var flying := _flying()

	ship.want_turn_left = Input.is_action_pressed("turn_left")
	ship.want_turn_right = Input.is_action_pressed("turn_right")
	ship.want_thrust = Input.is_action_pressed("thrust")
	ship.want_reverse_thrust = Input.is_action_pressed("reverse_thrust")
	ship.want_boost = Input.is_action_pressed("boost")
	if ship.want_turn_left or ship.want_turn_right or ship.want_thrust or ship.want_reverse_thrust:
		_locked = false
		ship.sleeping = false

	flying._update_particles()
	flying._update_camera_shake(delta)
	velocity_tween_time += delta

	if not _focus_alive():
		_get_pulse().emitting = false
		if _linger < 0.0:
			_linger = LINGER_AFTER_BREAK
		_linger -= delta
		if _linger <= 0.0:
			_exit_to_flying()
		return

	_get_pulse().emitting = focus.is_harvesting() and Input.is_action_pressed("action")

	# Left harvest range (only possible once the lock is released): drop focus.
	if not focus.is_harvesting() and not _focus_in_range():
		_exit_to_flying()

func integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not is_ship_valid():
		return
	# Collision damage, turning and thrust work exactly as in free flight.
	_flying().integrate_forces(state)

	if not _locked or not _focus_alive():
		return
	var resource_velocity: Vector2 = focus.get_orbital_velocity()
	var tween_progress: float = minf(velocity_tween_time / velocity_tween_duration, 1.0)
	state.linear_velocity = velocity_tween_start.lerp(resource_velocity, tween_progress)
	state.angular_velocity = 0.0

func _focus_alive() -> bool:
	return focus != null and is_instance_valid(focus) and not focus._is_depleted and focus.amount > 0

func _focus_in_range() -> bool:
	return ship.harvest_cone != null and ship.harvest_cone.has_scrap(focus)

func _flying() -> FlyingState:
	return ship.state_machine.states.get("FlyingState") as FlyingState

func _get_pulse() -> HarvestPulse:
	var pulse := ship.get_node_or_null("HarvestPulse") as HarvestPulse
	if not pulse:
		pulse = HarvestPulse.new()
		pulse.name = "HarvestPulse"
		ship.add_child(pulse)
	return pulse

func _exit_to_flying() -> void:
	var state_machine: StateMachine = ship.get_node_or_null("StateMachine") as StateMachine
	if state_machine and state_machine.has_state("FlyingState"):
		state_machine.change_state("FlyingState")
