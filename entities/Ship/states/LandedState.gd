extends ShipState
class_name LandedState

## Handles docking behavior when the ship is docked to a dockable entity.

# Dockable is an interface - we use Node2D and check for methods
var locked_dockable: Node2D = null
var locked_offset_from_target: Vector2 = Vector2.ZERO
var _docking_start_time: float = 0.0
var _docking_animation_duration: float = 0.5  # Duration of smooth docking animation
var _initial_ship_position: Vector2 = Vector2.ZERO
var _initial_ship_rotation: float = 0.0
var _dialogue = null  # SpacePortDialogue
var _terminal: CoreTerminal = null
var _cash_in: HoldCashIn = null
var _refueling := false

## Seconds for a port to fill an empty tank.
const REFUEL_TIME := 5.0

## Docked: `action` is the port's key, not the sonar's.
func allows_sonar() -> bool:
	return false

func enter() -> void:
	super.enter()

	if not is_ship_valid():
		return

	# Get dockable from ship's metadata (set by FlyingState or ShipSpawner)
	var pending_dockable = ship.get_meta("pending_dockable", null) as Node2D
	ship.remove_meta("pending_dockable")

	# Check for instant dock flag (set by ShipSpawner for spawning)
	var instant_dock = ship.get_meta("instant_dock", false)
	ship.remove_meta("instant_dock")

	if not pending_dockable or not is_instance_valid(pending_dockable):
		# No dockable provided, go back to flying
		_exit_to_flying()
		return

	# Verify it has dockable methods
	if not pending_dockable.has_method("get_dock_position") or not pending_dockable.has_method("get_dock_distance"):
		_exit_to_flying()
		return

	locked_dockable = pending_dockable
	locked_offset_from_target = Vector2.ZERO  # Will be calculated on first frame
	ship.drift_spin = 0.0  # docked is under control, whatever it was doing before

	if instant_dock:
		# Instant dock: skip animation by setting start time far in the past
		_docking_start_time = 0.0
		_initial_ship_position = ship.global_position
		_initial_ship_rotation = ship.rotation
	else:
		# Normal dock: animate from current position
		_docking_start_time = Time.get_ticks_msec() / 1000.0
		_initial_ship_position = ship.global_position
		_initial_ship_rotation = ship.rotation

	# Clear docking action message since we're now docked
	EventBus.action_message_changed.emit("")

	# Zoom camera in when docked
	if ship.camera:
		ship.camera.zoom_camera_in(Vector2(2.5, 2.5))
	
	var gs = ship.get_tree().get_first_node_in_group("game_state") as GameState

	# Space ports: refuel over time, fly the hold into the port as credits, refresh resources
	var at_port := locked_dockable.is_in_group("space_ports")
	# A port nobody runs takes no delivery: the hold keeps what it carries until someone
	# is awake to receive it (docs/OPENING.md §3, SpacePort.is_open).
	var port_open := at_port and _port_is_open()
	if at_port:
		_refueling = true
		if port_open:
			_cash_in = HoldCashIn.begin(locked_dockable, ship, gs)
			if _cash_in:
				_cash_in.finished.connect(_on_cash_in_finished)
		EventBus.resources_refresh_requested.emit()

	# Auto-save on landing (wait a frame to ensure position is set)
	await ship.get_tree().process_frame
	_autosave()

	# Automatically open SpacePort dialogue if docked to a SpacePort (but not on spawn),
	# once the cash-in has played out. A closed port opens nothing and prompts nothing:
	# the dock is a perch, and thrust is the way off it.
	if not instant_dock and port_open:
		if is_instance_valid(_cash_in):
			await _cash_in.finished
		if locked_dockable and is_instance_valid(locked_dockable):
			_open_spaceport_dialogue()
	elif instant_dock and port_open:
		_show_enter_spaceport_message()
	elif _awaiting_reboot():
		# SR-7 whole and its core cold: the dock's console is the only thing awake
		# (docs/OPENING.md §5), and it is what docking was for.
		if instant_dock:
			_show_terminal_message()
		else:
			_open_core_terminal()

func exit() -> void:
	super.exit()
	var cash_in := _cash_in
	_cash_in = null
	_refueling = false
	_close_core_terminal()
	# Close dialogue if open
	if _dialogue and is_instance_valid(_dialogue):
		if _dialogue.dialogue_closed.is_connected(_on_dialogue_closed):
			_dialogue.dialogue_closed.disconnect(_on_dialogue_closed)
		_dialogue.close_dialogue()
	_dialogue = null
	locked_dockable = null
	locked_offset_from_target = Vector2.ZERO
	_docking_start_time = 0.0
	_initial_ship_position = Vector2.ZERO
	_initial_ship_rotation = 0.0

	# Clear action message
	EventBus.action_message_changed.emit("")

	# Zoom camera out when undocking
	if ship and ship.camera:
		ship.camera.zoom_camera_out()

	# Taking off mid cash-in banks the rest immediately (after locked_dockable is
	# cleared, so the enter() coroutine waiting on it doesn't reopen the dialogue)
	if is_instance_valid(cash_in):
		cash_in.finish()

func physics_process(delta: float) -> void:
	if not is_ship_valid():
		return
	
	# Sample input to check if player wants to take off
	ship.want_thrust = Input.is_action_pressed("thrust")
	ship.want_reverse_thrust = Input.is_action_pressed("reverse_thrust")
	
	# Handle dialogue keypress (ui_accept - Space/Enter)
	# Don't toggle dialogue if store UI is open (Space is used for menu selection there)
	if Input.is_action_just_pressed("action") and not _is_store_open():
		if _awaiting_reboot():
			_toggle_core_terminal()
		else:
			_toggle_dialogue()
	
	# Release lock if thrusting - transition back to FlyingState
	# Don't allow takeoff if any UI is open (dialogue, store, etc.)
	var is_ui_blocking = (_dialogue and _dialogue.visible) or _is_store_open() or _is_terminal_open()
	if (ship.want_thrust or ship.want_reverse_thrust) and not is_ui_blocking:
		_exit_to_flying()
		return
	
	if _refueling:
		_refuel(delta)

	# Reset camera shake
	if ship.camera:
		ship.camera_shake_time = 0.0
		ship.damage_shake_time = 0.0
		ship.damage_shake_current_intensity = 0.0
		if ship.camera.offset != ship.camera_base_offset:
			ship.camera.offset = ship.camera.offset.lerp(ship.camera_base_offset, delta * 5.0)
	
	# Check if dockable is still valid and close enough
	if not locked_dockable or not is_instance_valid(locked_dockable):
		_exit_to_flying()
		return
	
	var dock_pos = locked_dockable.get_dock_position()
	var distance_to_dock = ship.global_position.distance_to(dock_pos)
	
	# If too far from dock, unlock
	if distance_to_dock > locked_dockable.get_dock_distance():
		_exit_to_flying()
		return

func integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not is_ship_valid() or not locked_dockable or not is_instance_valid(locked_dockable):
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_dock = current_time - _docking_start_time
	var animation_progress = min(1.0, time_since_dock / _docking_animation_duration)
	
	# Get dock position and velocity from dockable
	var target_pos = locked_dockable.get_dock_position()
	var target_vel = Vector2.ZERO
	if locked_dockable.has_method("get_dock_velocity"):
		target_vel = locked_dockable.get_dock_velocity()
	var dock_rotation = 0.0
	if locked_dockable.has_method("get_dock_rotation"):
		dock_rotation = locked_dockable.get_dock_rotation()
	else:
		dock_rotation = locked_dockable.global_rotation
	
	# Calculate target rotation (perpendicular to dock surface)
	var target_rotation = dock_rotation + PI / -2.0  # Perpendicular (90 degrees offset)
	
	# If we just locked, calculate offset to preserve X position and set Y flush on dock
	if locked_offset_from_target == Vector2.ZERO:
		# Transform ship position into dockable's local space to account for rotation
		var dockable_transform = locked_dockable.global_transform
		var ship_local_pos = dockable_transform.affine_inverse() * state.transform.origin
		# In local space, dock center is at (0, 0), so preserve X and set Y to -20
		locked_offset_from_target = Vector2(ship_local_pos.x, -20)
		# Transform offset back to world space
		locked_offset_from_target = dockable_transform.basis_xform(locked_offset_from_target)
	
	# Calculate desired position (target + offset)
	var desired_pos = target_pos + locked_offset_from_target
	
	# Smooth docking animation: lerp position and rotation during animation phase
	if animation_progress < 1.0:
		# Smoothly interpolate position
		var lerped_pos = _initial_ship_position.lerp(desired_pos, animation_progress)
		state.transform.origin = lerped_pos
		
		# Smoothly interpolate rotation
		var lerped_rotation = lerp_angle(_initial_ship_rotation, target_rotation, animation_progress)
		var cos_r = cos(lerped_rotation)
		var sin_r = sin(lerped_rotation)
		state.transform.x = Vector2(cos_r, sin_r)
		state.transform.y = Vector2(-sin_r, cos_r)
	else:
		# Animation complete - use rigid locking
		state.transform.origin = desired_pos
		var cos_r = cos(target_rotation)
		var sin_r = sin(target_rotation)
		state.transform.x = Vector2(cos_r, sin_r)
		state.transform.y = Vector2(-sin_r, cos_r)
	
	# Set velocity to match dockable
	state.linear_velocity = target_vel
	state.angular_velocity = 0.0

## Whether the port the ship is docked to is open for business. A dockable that is not a
## port at all is not, and neither is a port with nobody awake to run it.
func _port_is_open() -> bool:
	if not locked_dockable or not is_instance_valid(locked_dockable):
		return false
	if not locked_dockable.is_in_group("space_ports"):
		return false
	var port := locked_dockable as SpacePort
	return port != null and port.is_open()

func _open_spaceport_dialogue() -> void:
	# Only allow dialogue if docked to an open SpacePort
	if not _port_is_open():
		return

	# Find the SpacePort from the group (locked_dockable IS the SpacePort node)
	var space_ports = ship.get_tree().get_nodes_in_group("space_ports")
	var spaceport: SpacePort = null
	for sp in space_ports:
		if sp == locked_dockable:
			spaceport = sp as SpacePort
			break
	
	if not spaceport:
		return
	
	# Find dialogue in scene tree if not already cached
	if not _dialogue or not is_instance_valid(_dialogue):
		# Get the current scene (Main node)
		var current_scene = ship.get_tree().current_scene
		if current_scene:
			var canvas_layer = current_scene.get_node_or_null("CanvasLayer")
			if canvas_layer:
				_dialogue = canvas_layer.get_node_or_null("SpacePortDialogue")
	
	if _dialogue and _dialogue.has_method("open_dialogue"):
		if not _dialogue.dialogue_closed.is_connected(_on_dialogue_closed):
			_dialogue.dialogue_closed.connect(_on_dialogue_closed)
		_dialogue.open_dialogue(spaceport)

func _toggle_dialogue() -> void:
	# Only allow dialogue if docked to an open SpacePort
	if not _port_is_open():
		return

	# Find dialogue in scene tree if not already cached
	if not _dialogue or not is_instance_valid(_dialogue):
		# Get the current scene (Main node)
		var current_scene = ship.get_tree().current_scene
		if current_scene:
			var canvas_layer = current_scene.get_node_or_null("CanvasLayer")
			if canvas_layer:
				_dialogue = canvas_layer.get_node_or_null("SpacePortDialogue")
	
	if _dialogue and _dialogue.has_method("open_dialogue"):
		if not _dialogue.dialogue_closed.is_connected(_on_dialogue_closed):
			_dialogue.dialogue_closed.connect(_on_dialogue_closed)
		if _dialogue.visible:
			_dialogue.close_dialogue()
		else:
			# Find the SpacePort from the group (locked_dockable IS the SpacePort node)
			var space_ports = ship.get_tree().get_nodes_in_group("space_ports")
			var spaceport: SpacePort = null
			for sp in space_ports:
				if sp == locked_dockable:
					spaceport = sp as SpacePort
					break

			if spaceport:
				_dialogue.open_dialogue(spaceport)

func _refuel(delta: float) -> void:
	ship.fuel = minf(ship.fuel + ship.max_fuel / REFUEL_TIME * delta, ship.max_fuel)
	ship.fuel_changed.emit()
	if ship.fuel >= ship.max_fuel:
		_refueling = false
		_autosave()

func _on_cash_in_finished(_total: int) -> void:
	_autosave()

func _autosave() -> void:
	if not is_ship_valid():
		return
	var gs = ship.get_tree().get_first_node_in_group("game_state") as GameState
	if not gs:
		return
	var hud = ship.get_tree().get_first_node_in_group("hud") as Control
	if hud and hud.has_method("show_saving_indicator"):
		hud.show_saving_indicator()
	Save.save(gs, ship)
	if hud and hud.has_method("hide_saving_indicator"):
		await ship.get_tree().create_timer(0.5).timeout
		if is_instance_valid(hud):
			hud.hide_saving_indicator()

func _exit_to_flying() -> void:
	var state_machine = ship.get_node_or_null("StateMachine") as StateMachine
	if state_machine and state_machine.has_state("FlyingState"):
		state_machine.change_state("FlyingState")

# --- SR-7's core terminal -------------------------------------------------------

## The core behind the port the ship is docked to, if that port is on a station with one.
func _port_core() -> CoreHousing:
	if not locked_dockable or not is_instance_valid(locked_dockable):
		return null
	var node: Node = locked_dockable.get_parent()
	while node:
		var core := node.get_node_or_null("CoreHousing") as CoreHousing
		if core:
			return core
		node = node.get_parent()
	return null

## Docked at a port nobody runs yet, on a station whose core is whole and waiting.
func _awaiting_reboot() -> bool:
	if _port_is_open() or not locked_dockable or not locked_dockable.is_in_group("space_ports"):
		return false
	var core := _port_core()
	return core != null and core.listens()

func _find_terminal() -> CoreTerminal:
	if not _terminal or not is_instance_valid(_terminal):
		_terminal = ship.get_tree().get_first_node_in_group("core_terminal") as CoreTerminal
	return _terminal

func _open_core_terminal() -> void:
	var terminal := _find_terminal()
	if not terminal:
		return
	if not terminal.reboot_requested.is_connected(_on_reboot_requested):
		terminal.reboot_requested.connect(_on_reboot_requested)
	if not terminal.terminal_closed.is_connected(_on_terminal_closed):
		terminal.terminal_closed.connect(_on_terminal_closed)
	EventBus.action_message_changed.emit("")
	terminal.open()

func _close_core_terminal() -> void:
	var terminal := _terminal
	if not terminal or not is_instance_valid(terminal):
		return
	if terminal.terminal_closed.is_connected(_on_terminal_closed):
		terminal.terminal_closed.disconnect(_on_terminal_closed)
	if terminal.reboot_requested.is_connected(_on_reboot_requested):
		terminal.reboot_requested.disconnect(_on_reboot_requested)
	terminal.close()

func _toggle_core_terminal() -> void:
	if _is_terminal_open():
		if not _terminal.is_running():
			_terminal.close()
	else:
		_open_core_terminal()

func _is_terminal_open() -> bool:
	return _terminal != null and is_instance_valid(_terminal) and _terminal.visible

func _show_terminal_message() -> void:
	EventBus.action_message_changed.emit(EventBus.action_prompt("TERMINAL"))

func _on_terminal_closed() -> void:
	if _awaiting_reboot():
		_show_terminal_message()

## The console asked for it: the core reboots, and the camera pulls back so the player
## watches the power come up across the station from where they sit. Once the dish has
## pinged the port is open, and docking is met by someone at last.
func _on_reboot_requested() -> void:
	var core := _port_core()
	if not core or not core.reboot():
		return
	EventBus.action_message_changed.emit("")
	if ship.camera:
		ship.camera.zoom_camera_out()
	await EventBus.core_started
	var power := core.get_parent().get_node_or_null("StationPower") as StationPower
	if power:
		await power.woken
	if not is_ship_valid() or not locked_dockable or not is_instance_valid(locked_dockable):
		return
	if ship.camera:
		ship.camera.zoom_camera_in(Vector2(2.5, 2.5))
	if _port_is_open():
		var gs := ship.get_tree().get_first_node_in_group("game_state") as GameState
		_cash_in = HoldCashIn.begin(locked_dockable, ship, gs)
		if _cash_in:
			_cash_in.finished.connect(_on_cash_in_finished)
		_show_enter_spaceport_message()

func _show_enter_spaceport_message() -> void:
	EventBus.action_message_changed.emit(EventBus.action_prompt("ENTER PORT"))

func _on_dialogue_closed() -> void:
	_show_enter_spaceport_message()

func _is_store_open() -> bool:
	if not ship or not is_instance_valid(ship):
		return false
	var tree = ship.get_tree()
	if not tree:
		return false
	var store_ui = tree.get_first_node_in_group("store_ui") as StoreUI
	return store_ui and store_ui.visible
