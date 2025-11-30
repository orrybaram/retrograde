extends RigidBody2D
class_name SpacePort

## SpacePort entity with landing pad, blinking lights, tower, and hangers.
## Detects when ships land on the pad.

signal ship_landed(ship: Ship)
signal ship_took_off(ship: Ship)

@export var landing_pad_size: Vector2 = Vector2(100, 20)
@export var light_blink_rate: float = 1.0  # Blink rate in seconds
@export var landing_lock_distance: float = 20.0  # Distance threshold for landing lock (pixels above pad)

var _landing_area: Area2D = null
var _ship_on_pad: Ship = null
var _left_light: ColorRect = null
var _right_light: ColorRect = null
var _blink_tween: Tween = null

func _ready() -> void:
	add_to_group("space_ports")
	
	# Set RigidBody2D to static mode (doesn't move due to physics)
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true
	
	# Get references to components
	_landing_area = get_node_or_null("LandingArea") as Area2D
	_left_light = get_node_or_null("LeftLight") as ColorRect
	_right_light = get_node_or_null("RightLight") as ColorRect
	
	# Set up landing area signals
	if _landing_area:
		_landing_area.body_entered.connect(_on_body_entered)
		_landing_area.body_exited.connect(_on_body_exited)
	
	# Start blinking animation
	_start_blink_animation()

func _on_body_entered(body: Node2D) -> void:
	if body is Ship:
		var ship = body as Ship
		_check_landing(ship)

func _on_body_exited(body: Node2D) -> void:
	if body is Ship:
		if body == _ship_on_pad:
			var ship = body as Ship
			_ship_on_pad = null
			ship_took_off.emit(ship)

func _check_landing(ship: Ship) -> void:
	if _ship_on_pad:
		return  # Already have a ship on pad
	
	# Check if ship is in landed state or moving slowly
	var state_machine = ship.get_node_or_null("StateMachine") as StateMachine
	var is_landed = false
	
	if state_machine:
		var current_state_name = state_machine.get_current_state_name()
		if current_state_name == "LandedState":
			is_landed = true
	
	# Also check velocity as fallback
	var velocity = ship.linear_velocity.length()
	var is_slow = velocity < 50.0
	
	if is_landed or is_slow:
		_ship_on_pad = ship
		ship_landed.emit(ship)

func _start_blink_animation() -> void:
	if not _left_light or not _right_light:
		return
	
	# Create tween for blinking animation
	if _blink_tween:
		_blink_tween.kill()
	
	_blink_tween = create_tween()
	_blink_tween.set_loops()  # Loop forever
	_blink_tween.set_parallel(true)
	
	# Animate both lights synchronously - fade out then fade in
	var half_duration = light_blink_rate * 0.5
	_blink_tween.tween_property(_left_light, "modulate:a", 0.3, half_duration)
	_blink_tween.tween_property(_left_light, "modulate:a", 1.0, half_duration).set_delay(half_duration)
	
	_blink_tween.tween_property(_right_light, "modulate:a", 0.3, half_duration)
	_blink_tween.tween_property(_right_light, "modulate:a", 1.0, half_duration).set_delay(half_duration)

## Get the landing pad position in world space
func get_landing_pad_position() -> Vector2:
	return global_position  # Landing pad is at (0,0) relative to SpacePort
