extends ShipState
class_name GateDockedState

## The ship clamped into a Gate's docking cradle. (LandedState is a port; this is a Gate.)
##
## A Gate is not a port: there is no quartermaster, nothing to sell and no fuel line.
## All that is out here is the Gate's own terminal, which opens on arrival and asks for
## the credits to bring the planet's Module online. The launch key releases the ship the
## same way a port does.

const CAMERA_ZOOM := Vector2(2.0, 2.0)
const DOCK_ANIM_TIME := 0.5

var locked_dockable: Node2D = null

var _offset_from_dock := Vector2.ZERO
var _dock_start_time := 0.0
var _start_position := Vector2.ZERO
var _start_rotation := 0.0
var _terminal: GateTerminal = null

func enter() -> void:
	super.enter()
	if not is_ship_valid():
		return

	var pending := _take_meta("pending_dockable", null) as Node2D
	var instant := bool(_take_meta("instant_dock", false))

	if not is_instance_valid(pending) or not pending.is_in_group("gates"):
		_exit_to_flying()
		return

	locked_dockable = pending
	_offset_from_dock = Vector2.ZERO
	_dock_start_time = 0.0 if instant else Time.get_ticks_msec() / 1000.0
	_start_position = ship.global_position
	_start_rotation = ship.rotation

	EventBus.action_message_changed.emit("")
	if ship.camera:
		ship.camera.zoom_camera_in(CAMERA_ZOOM)

	# Reaching a Gate is what names it. In open flight that has already happened long
	# before the cradle, but a ship that spawns docked at one skips the approach, so the
	# Guide gets its word in before the terminal takes the screen.
	var gate := locked_dockable as Gate
	if gate:
		gate.identify()

	if instant:
		_show_prompt()
	else:
		_open_terminal()

## Read one of the hand-over values FlyingState or ShipSpawner left on the ship, and
## clear it so the next dock starts clean.
func _take_meta(key: String, fallback: Variant) -> Variant:
	if not ship.has_meta(key):
		return fallback
	var value: Variant = ship.get_meta(key)
	ship.remove_meta(key)
	return value

func exit() -> void:
	super.exit()
	_close_terminal()
	locked_dockable = null
	_offset_from_dock = Vector2.ZERO
	_dock_start_time = 0.0
	EventBus.action_message_changed.emit("")
	if ship and ship.camera:
		ship.camera.zoom_camera_out()

func physics_process(_delta: float) -> void:
	if not is_ship_valid():
		return

	if not is_instance_valid(locked_dockable):
		_exit_to_flying()
		return

	# Drifting out of the cradle's reach releases the lock, same as a port
	if ship.global_position.distance_to(locked_dockable.get_dock_position()) > locked_dockable.get_dock_distance():
		_exit_to_flying()
		return

	ship.want_thrust = Input.is_action_pressed("thrust")
	ship.want_reverse_thrust = Input.is_action_pressed("reverse_thrust")

	# The terminal owns the keyboard while it is up: the launch key is its skip key too
	if is_terminal_open():
		return

	if ship.want_thrust or ship.want_reverse_thrust:
		_exit_to_flying()
		return

	if Input.is_action_just_pressed("action"):
		_open_terminal()

## Holds the ship in the cradle: lerped in on arrival, rigid after that, riding the
## Gate's orbit.
func integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not is_ship_valid() or not is_instance_valid(locked_dockable):
		return

	var dock := gate_dock_transform(locked_dockable)
	var target_rotation := dock.get_rotation() + PI / -2.0

	if _offset_from_dock == Vector2.ZERO:
		var local := dock.affine_inverse() * state.transform.origin
		_offset_from_dock = dock.basis_xform(Vector2(local.x, -20))

	var desired := dock.origin + _offset_from_dock
	var progress := minf(1.0, (Time.get_ticks_msec() / 1000.0 - _dock_start_time) / DOCK_ANIM_TIME)
	var pos := _start_position.lerp(desired, progress) if progress < 1.0 else desired
	var rot := lerp_angle(_start_rotation, target_rotation, progress) if progress < 1.0 else target_rotation

	state.transform = Transform2D(rot, pos)
	state.linear_velocity = locked_dockable.get_dock_velocity()
	state.angular_velocity = 0.0

## The cradle's frame, falling back to the node's own for anything that only
## implements the plain Dockable methods.
static func gate_dock_transform(dockable: Node2D) -> Transform2D:
	if dockable.has_method("get_dock_transform"):
		return dockable.get_dock_transform()
	return Transform2D(dockable.get_dock_rotation(), dockable.get_dock_position())

# --- Terminal ----------------------------------------------------------------

func is_terminal_open() -> bool:
	return is_instance_valid(_terminal) and _terminal.visible

func _open_terminal() -> void:
	var gate := locked_dockable as Gate
	if not gate:
		return
	if not is_instance_valid(_terminal):
		_terminal = ship.get_tree().get_first_node_in_group("gate_terminal") as GateTerminal
	if not is_instance_valid(_terminal):
		_show_prompt()
		return
	if not _terminal.terminal_closed.is_connected(_on_terminal_closed):
		_terminal.terminal_closed.connect(_on_terminal_closed)
	if not _terminal.gate_powered.is_connected(_on_gate_powered):
		_terminal.gate_powered.connect(_on_gate_powered)
	EventBus.action_message_changed.emit("")
	_terminal.open(gate)

func _close_terminal() -> void:
	if not is_instance_valid(_terminal):
		_terminal = null
		return
	if _terminal.terminal_closed.is_connected(_on_terminal_closed):
		_terminal.terminal_closed.disconnect(_on_terminal_closed)
	if _terminal.gate_powered.is_connected(_on_gate_powered):
		_terminal.gate_powered.disconnect(_on_gate_powered)
	_terminal.close()
	_terminal = null

func _on_terminal_closed() -> void:
	if ship and ship.state_machine and ship.state_machine.current_state == self:
		_show_prompt()

## The Module coming online is felt through the hull, not taken out of it: one bump,
## one twitch across the readouts, no damage. The guide has nothing to say about it.
func _on_gate_powered(_gate: Gate) -> void:
	if not is_ship_valid():
		return
	ship.damage_shake_time = ship.harvest_lockon_shake_duration
	ship.damage_shake_current_intensity = ship.harvest_lockon_shake_intensity
	var hud := ship.get_tree().get_first_node_in_group("hud") as Control
	if hud:
		var glitch := hud.get_node_or_null("HudGlitch") as HudGlitch
		if glitch:
			glitch.hit(0.45)
	_autosave()

func _show_prompt() -> void:
	EventBus.action_message_changed.emit("%s   %s" % [
		EventBus.key_prompt("thrust", "LIFT OFF"),
		EventBus.action_prompt("TERMINAL"),
	])

## A Module coming online is worth keeping even if the session ends here.
func _autosave() -> void:
	var gs := ship.get_tree().get_first_node_in_group("game_state") as GameState
	if not gs:
		return
	var hud := ship.get_tree().get_first_node_in_group("hud") as Control
	if hud and hud.has_method("show_saving_indicator"):
		hud.show_saving_indicator()
	Save.save(gs, ship)
	if hud and hud.has_method("hide_saving_indicator"):
		await ship.get_tree().create_timer(0.5).timeout
		if is_instance_valid(hud):
			hud.hide_saving_indicator()

func _exit_to_flying() -> void:
	var machine := ship.get_node_or_null("StateMachine") as StateMachine
	if machine and machine.has_state("FlyingState"):
		machine.change_state("FlyingState")
