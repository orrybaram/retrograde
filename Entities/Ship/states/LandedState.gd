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
	
	# Auto-save on landing (wait a frame to ensure position is set)
	await ship.get_tree().process_frame
	var gs = ship.get_tree().get_first_node_in_group("game_state") as GameState
	if gs and ship:
		# Show saving indicator
		var hud = ship.get_tree().get_first_node_in_group("hud") as Control
		if hud and hud.has_method("show_saving_indicator"):
			hud.show_saving_indicator()
		
		Save.save(gs, ship)
		
		# Hide saving indicator after a brief delay
		if hud and hud.has_method("hide_saving_indicator"):
			await ship.get_tree().create_timer(0.5).timeout
			hud.hide_saving_indicator()
	
	# Automatically open SpacePort dialogue if docked to a SpacePort (but not on spawn)
	if not instant_dock and locked_dockable and is_instance_valid(locked_dockable) and locked_dockable.is_in_group("space_ports"):
		_open_spaceport_dialogue()

func exit() -> void:
	super.exit()
	# Close dialogue if open
	if _dialogue and is_instance_valid(_dialogue):
		_dialogue.close_dialogue()
	_dialogue = null
	locked_dockable = null
	locked_offset_from_target = Vector2.ZERO
	_docking_start_time = 0.0
	_initial_ship_position = Vector2.ZERO
	_initial_ship_rotation = 0.0
	
	# Clear action message
	EventBus.action_message_changed.emit("")

func physics_process(delta: float) -> void:
	if not is_ship_valid():
		return
	
	# Sample input to check if player wants to take off
	ship.want_thrust = Input.is_action_pressed("thrust")
	ship.want_reverse_thrust = Input.is_action_pressed("reverse_thrust")
	
	# Handle dialogue keypress (ui_accept - Space/Enter)
	if Input.is_action_just_pressed("action"):
		_toggle_dialogue()
	
	# Release lock if thrusting - transition back to FlyingState
	# Don't allow takeoff if dialogue is open
	if (ship.want_thrust or ship.want_reverse_thrust) and not (_dialogue and _dialogue.visible):
		_exit_to_flying()
		return
	
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

func _open_spaceport_dialogue() -> void:
	# Only allow dialogue if docked to a SpacePort
	if not locked_dockable or not is_instance_valid(locked_dockable):
		return
	
	# Check if dockable is a SpacePort by checking if it's in the space_ports group
	if not locked_dockable.is_in_group("space_ports"):
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
		_dialogue.open_dialogue(spaceport)

func _toggle_dialogue() -> void:
	# Only allow dialogue if docked to a SpacePort
	if not locked_dockable or not is_instance_valid(locked_dockable):
		return
	
	# Check if dockable is a SpacePort by checking if it's in the space_ports group
	if not locked_dockable.is_in_group("space_ports"):
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

func _exit_to_flying() -> void:
	var state_machine = ship.get_node_or_null("StateMachine") as StateMachine
	if state_machine and state_machine.has_state("FlyingState"):
		state_machine.change_state("FlyingState")
