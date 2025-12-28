extends ShipState
class_name LandedState

## Handles SpacePort locking behavior when the ship is landed on a SpacePort.

var locked_spaceport: SpacePort = null
var locked_offset_from_target: Vector2 = Vector2.ZERO
var _spaceport_rotation_set: bool = false
var _dialogue = null  # SpacePortDialogue

func enter() -> void:
	super.enter()
	
	if not is_ship_valid():
		return
	
	# Find closest SpacePort to lock to
	var space_ports = ship.get_tree().get_nodes_in_group("space_ports")
	if space_ports.is_empty():
		# No SpacePorts, go back to flying
		_exit_to_flying()
		return
	
	var closest_spaceport: SpacePort = null
	var closest_distance: float = INF
	var ship_pos = ship.global_position
	
	for node in space_ports:
		if not is_instance_valid(node):
			continue
		var spaceport = node as SpacePort
		if not spaceport:
			continue
		
		var pad_pos = spaceport.get_landing_pad_position()
		var dist = ship_pos.distance_to(pad_pos)
		
		if dist < closest_distance:
			closest_distance = dist
			closest_spaceport = spaceport
	
	if closest_spaceport and is_instance_valid(closest_spaceport):
		locked_spaceport = closest_spaceport
		locked_offset_from_target = Vector2.ZERO  # Will be calculated on first frame
		_spaceport_rotation_set = false  # Reset rotation flag
		
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
		
		# Emit action message for space port entry
		var enter_key = InputUtils.get_action_key_name("action")
		EventBus.action_message_changed.emit('Press "%s" to enter' % [enter_key])

func exit() -> void:
	super.exit()
	# Close dialogue if open
	if _dialogue and is_instance_valid(_dialogue):
		_dialogue.close_dialogue()
	_dialogue = null
	locked_spaceport = null
	locked_offset_from_target = Vector2.ZERO
	_spaceport_rotation_set = false
	
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
	
	# Check if SpacePort is still valid and close enough
	if not locked_spaceport or not is_instance_valid(locked_spaceport):
		_exit_to_flying()
		return
	
	var pad_pos = locked_spaceport.get_landing_pad_position()
	var distance_to_pad = ship.global_position.distance_to(pad_pos)
	
	# If too far from pad, unlock
	if distance_to_pad > locked_spaceport.landing_lock_distance:
		_exit_to_flying()
		return

func integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not is_ship_valid() or not locked_spaceport or not is_instance_valid(locked_spaceport):
		return
	
	# Lock to SpacePort landing pad
	var target_pos = locked_spaceport.get_landing_pad_position()
	
	# Get SpacePort's velocity (it moves with its parent planet)
	var target_vel = Vector2.ZERO
	var spaceport_parent = locked_spaceport.get_parent()
	if spaceport_parent is RigidBody2D:
		target_vel = (spaceport_parent as RigidBody2D).linear_velocity
	
	# If we just locked, calculate offset to preserve X position and set Y flush on pad
	if locked_offset_from_target == Vector2.ZERO:
		# Transform ship position into SpacePort's local space to account for rotation
		var spaceport_transform = locked_spaceport.global_transform
		var ship_local_pos = spaceport_transform.affine_inverse() * state.transform.origin
		# In local space, pad center is at (0, 0), so preserve X and set Y to -20
		locked_offset_from_target = Vector2(ship_local_pos.x, -20)
		# Transform offset back to world space
		locked_offset_from_target = spaceport_transform.basis_xform(locked_offset_from_target)
	
	# Maintain the offset and update position to follow SpacePort
	var desired_pos = target_pos + locked_offset_from_target
	
	# Set position and velocity to match SpacePort
	state.linear_velocity = target_vel
	state.angular_velocity = 0.0
	
	# Set position
	state.transform.origin = desired_pos
	
	# Align ship rotation to be perpendicular to SpacePort (only on first frame of lock)
	if not _spaceport_rotation_set:
		# Ship should be perpendicular to the SpacePort's rotation
		# If SpacePort is horizontal (0°), ship should be vertical (90°)
		var spaceport_rotation = locked_spaceport.global_rotation
		var target_rotation = spaceport_rotation + PI / -2.0  # Perpendicular (90 degrees offset)
		# Set rotation by creating new basis vectors
		var cos_r = cos(target_rotation)
		var sin_r = sin(target_rotation)
		state.transform.x = Vector2(cos_r, sin_r)
		state.transform.y = Vector2(-sin_r, cos_r)
		_spaceport_rotation_set = true

func _toggle_dialogue() -> void:
	if not locked_spaceport or not is_instance_valid(locked_spaceport):
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
			_dialogue.open_dialogue(locked_spaceport)

func _exit_to_flying() -> void:
	var state_machine = ship.get_node_or_null("StateMachine") as StateMachine
	if state_machine and state_machine.has_state("FlyingState"):
		state_machine.change_state("FlyingState")
