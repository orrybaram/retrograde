extends ShipState
class_name HarvestingState

## Handles velocity locking when the ship is harvesting resource nodes.
## Multiple scraps may be harvested simultaneously; velocity locks to the nearest one.

var locked_resource_nodes: Array[ScrapNode] = []
var velocity_tween_start: Vector2 = Vector2.ZERO
var velocity_tween_time: float = 0.0
var velocity_tween_duration: float = 2.0
var _shake_grace_time: float = 0.0
var camera_zoom_in: Vector2 = Vector2(1.5, 1.5)

func enter() -> void:
	super.enter()

	if not is_ship_valid():
		return

	ship.camera.zoom_camera_in(camera_zoom_in)

	ship.damage_shake_time = ship.harvest_lockon_shake_duration
	ship.damage_shake_current_intensity = ship.harvest_lockon_shake_intensity
	_shake_grace_time = ship.harvest_lockon_shake_duration

	_get_pulse().emitting = Input.is_action_pressed("action")

	velocity_tween_start = ship.linear_velocity
	velocity_tween_time = 0.0

	_cleanup_locked_nodes()
	if locked_resource_nodes.is_empty():
		_exit_to_flying()

func exit() -> void:
	super.exit()
	locked_resource_nodes.clear()
	velocity_tween_time = 0.0
	velocity_tween_start = Vector2.ZERO

	ship.camera.zoom_camera_out()

	_get_pulse().emitting = false

func add_locked_node(scrap: ScrapNode) -> void:
	if not locked_resource_nodes.has(scrap):
		locked_resource_nodes.append(scrap)

func physics_process(delta: float) -> void:
	if not is_ship_valid():
		return

	ship.want_thrust = Input.is_action_pressed("thrust")
	ship.want_reverse_thrust = Input.is_action_pressed("reverse_thrust")

	if ship.want_thrust or ship.want_reverse_thrust:
		_exit_to_flying()
		return

	_cleanup_locked_nodes()

	if locked_resource_nodes.is_empty():
		_exit_to_flying()
		return

	_get_pulse().emitting = Input.is_action_pressed("action")
	velocity_tween_time += delta

	if _shake_grace_time > 0.0:
		_shake_grace_time -= delta
	else:
		if ship.camera:
			ship.camera_shake_time = 0.0
			ship.damage_shake_time = 0.0
			ship.damage_shake_current_intensity = 0.0
			if ship.camera.offset != ship.camera_base_offset:
				ship.camera.offset = ship.camera.offset.lerp(ship.camera_base_offset, delta * 5.0)

func integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not is_ship_valid() or locked_resource_nodes.is_empty():
		return

	var primary := _get_nearest_locked_node()
	if not primary:
		return

	var resource_velocity: Vector2 = primary.get_orbital_velocity()
	var tween_progress: float = minf(velocity_tween_time / velocity_tween_duration, 1.0)
	state.linear_velocity = velocity_tween_start.lerp(resource_velocity, tween_progress)
	state.angular_velocity = 0.0

func _cleanup_locked_nodes() -> void:
	var cleaned: Array[ScrapNode] = []
	for n in locked_resource_nodes:
		if is_instance_valid(n) and n.is_harvesting():
			cleaned.append(n)
	locked_resource_nodes = cleaned

func _get_nearest_locked_node() -> ScrapNode:
	if locked_resource_nodes.is_empty():
		return null
	if not is_ship_valid():
		return locked_resource_nodes[0]
	var nearest: ScrapNode = null
	var nearest_dist := INF
	for node in locked_resource_nodes:
		if not is_instance_valid(node):
			continue
		var d := ship.global_position.distance_squared_to(node.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = node
	return nearest

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
