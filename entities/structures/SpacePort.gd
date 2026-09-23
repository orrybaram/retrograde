extends StaticBody2D
class_name SpacePort

## SpacePort entity with landing pad, blinking lights, tower, and hangers.
## Detects when ships land on the pad.
## Implements Dockable interface for manual docking.

const Dockable = preload("res://entities/structures/Dockable.gd")

signal ship_landed(ship: Ship)
signal ship_took_off(ship: Ship)

## A port nobody is awake to run. SR-7 opens like this (docs/OPENING.md §3, §5): the
## station is dead, UNIT-7 is off in the cold core, and a ship that docks is met by
## nothing at all - no hub, no prompt for one, and no hold taken in, because there is
## nobody there to take delivery. The core's cold start opens it for good.
## Ports with nobody to wake (the Sun Station's pair) leave this false.
@export var needs_core := false

@export var landing_pad_size: Vector2 = Vector2(100, 20)
@export var light_blink_rate: float = 1.0  # Blink rate in seconds
@export var landing_lock_distance: float = 60.0  # Distance threshold for landing lock (pixels above pad)
## Where a docked ship's centre sits, in the port's own space: out along the pad's face far
## enough that the whole ship clears the pad, rather than its tail sunk into it.
@export var dock_offset := Vector2.ZERO

var _landing_area: Area2D = null
var _ship_on_pad: Ship = null
var _left_light: Polygon2D = null
var _right_light: Polygon2D = null
var _blink_tween: Tween = null
## How an unlit lamp shows: its glass, dark (a tint over the lamp's own colour).
const UNLIT := Colors.HULL_MID

func _ready() -> void:
	add_to_group("space_ports")
	add_to_group("dockable")
	
	
	# Get references to components
	_landing_area = get_node_or_null("LandingArea") as Area2D
	_left_light = get_node_or_null("LeftLight") as Polygon2D
	_right_light = get_node_or_null("RightLight") as Polygon2D
	
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

## Lamps on or off. A dead station's dock (SR-7 before power, StationPower) is dark: the
## lamps stop blinking and go to unlit glass.
func set_lit(on: bool) -> void:
	if not _left_light or not _right_light:
		return
	if on:
		_left_light.modulate = Color.WHITE
		_right_light.modulate = Color.WHITE
		if _blink_tween == null or not _blink_tween.is_valid():
			_start_blink_animation()
		return
	if _blink_tween:
		_blink_tween.kill()
		_blink_tween = null
	_left_light.modulate = UNLIT
	_right_light.modulate = UNLIT

## Whether docking here is met by anyone: the hub opens, the hold is taken in. False on
## SR-7 until its core is cold-started (`needs_core`). The gate is the world's state,
## not the radio's - `RobotRadio.guide_awake` only governs whether UNIT-7's tips play.
func is_open() -> bool:
	if not needs_core:
		return true
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	return gs != null and gs.core_started

## Get the landing pad position in world space
func get_landing_pad_position() -> Vector2:
	return global_position  # Landing pad is at (0,0) relative to SpacePort

## Dockable interface implementation
func get_dock_position() -> Vector2:
	return to_global(dock_offset)

func get_dock_rotation() -> float:
	return global_rotation

func get_dock_distance() -> float:
	return landing_lock_distance

func get_dock_velocity() -> Vector2:
	# Get SpacePort's velocity (it moves with its parent planet)
	var parent = get_parent()
	if parent is RigidBody2D:
		return (parent as RigidBody2D).linear_velocity
	return Vector2.ZERO
