extends Node
class_name OrbitalMotion

## Composable node that handles orbital mechanics for its parent.
## Add as a child to any Node2D/RigidBody2D to make it orbit around another body.
##
## Usage modes:
## 1. Auto-detection: Add as child, it finds parent's parent as orbital body
## 2. Manual setup: Call initialize(body) with orbital parameters
## 3. Spawner workflow: Set orbital params, then call initialize(body)

signal orbit_updated(angle: float, position: Vector2, velocity: Vector2)

enum PositionMode {
	LOCAL,  ## Update parent.position (relative to orbital body, when parent is child of orbital body)
	GLOBAL  ## Update parent.global_position (when parent is NOT a child of orbital body)
}

# Orbital parameters (exported for editor configuration)
@export var orbital_distance: float = 500.0  ## Distance from orbital center
@export_range(0, 100) var orbital_speed: float = 5.0  ## Speed scale (0 = static, 100 = fastest)
@export var initial_angle: float = 0.0  ## Starting angle in radians
@export var eccentricity: float = 0.0  ## 0.0 for circular, >0.0 for elliptical (0.0-0.99)
@export var enable_orbiting: bool = true  ## Toggle orbital motion on/off
@export var speed_scale: float = 0.01  ## Multiplier to convert speed (0-100) to radians/sec
@export var position_mode: PositionMode = PositionMode.LOCAL  ## How to update position
@export var update_velocity: bool = true  ## Whether to update linear_velocity for RigidBody2D
@export var auto_initialize: bool = true  ## Auto-init in _ready using parent's parent

# Runtime state
var orbital_body: Node2D = null  ## The body we orbit around
var orbital_angle: float = 0.0
var orbital_start_time: float = 0.0
var initialized: bool = false  ## Public for spawner access

## Get the parent node we're controlling
func get_orbital_parent() -> Node2D:
	return get_parent() as Node2D

## Convert orbital speed from 0-100 scale to radians per second
func get_speed_radians_per_second() -> float:
	return (orbital_speed / 100.0) * speed_scale

## Initialize orbital motion. Call this after setting orbital parameters.
## @param body The body to orbit around. If null, uses previously set orbital_body.
## @param start_angle Optional starting angle (uses initial_angle if not provided)
func initialize(body: Node2D = null, start_angle: float = NAN) -> void:
	if body:
		orbital_body = body
	if not is_nan(start_angle):
		initial_angle = start_angle
	orbital_angle = initial_angle
	orbital_start_time = Time.get_ticks_msec() / 1000.0
	initialized = true

## Configure all orbital parameters at once (useful for spawners)
func configure(distance: float, speed: float, angle: float, ecc: float = 0.0) -> void:
	orbital_distance = distance
	orbital_speed = speed
	initial_angle = angle
	eccentricity = ecc

func _ready() -> void:
	if not auto_initialize:
		return
	
	# Auto-detect orbital body: if parent's parent is a valid body, use it
	var parent = get_orbital_parent()
	if parent:
		var grandparent = parent.get_parent()
		if grandparent is Node2D:
			orbital_body = grandparent as Node2D
			initialize()

func _physics_process(_delta: float) -> void:
	update_orbit()

## Core orbital update - call this manually if you want more control over timing
func update_orbit() -> void:
	if not enable_orbiting or not initialized or not orbital_body:
		return
	
	if not is_instance_valid(orbital_body):
		return
	
	var parent = get_orbital_parent()
	if not parent:
		return
	
	# Calculate time-based orbital angle (deterministic)
	var speed_rad_per_sec = get_speed_radians_per_second()
	var elapsed = Time.get_ticks_msec() / 1000.0 - orbital_start_time
	orbital_angle = fmod(initial_angle + speed_rad_per_sec * elapsed, TAU)
	
	# Calculate orbital offset
	var orbital_offset = calculate_orbital_offset()
	
	# Calculate orbital velocity
	var orbital_velocity = calculate_orbital_velocity(speed_rad_per_sec)
	
	# Update parent's position based on mode
	match position_mode:
		PositionMode.LOCAL:
			parent.position = orbital_offset
		PositionMode.GLOBAL:
			parent.global_position = orbital_body.global_position + orbital_offset
	
	# If parent is RigidBody2D and velocity updates enabled, set velocity
	if update_velocity and parent is RigidBody2D:
		var rigid_parent = parent as RigidBody2D
		# Add orbital body's velocity for nested orbits (moons inherit planet velocity)
		if orbital_body is RigidBody2D:
			rigid_parent.linear_velocity = (orbital_body as RigidBody2D).linear_velocity + orbital_velocity
		else:
			rigid_parent.linear_velocity = orbital_velocity
	
	# Emit signal for any listeners
	orbit_updated.emit(orbital_angle, orbital_offset, orbital_velocity)

## Calculate the orbital offset vector based on current angle
func calculate_orbital_offset() -> Vector2:
	if eccentricity == 0.0:
		# Circular orbit
		return Vector2(cos(orbital_angle), sin(orbital_angle)) * orbital_distance
	else:
		# Elliptical orbit using true elliptical formula with focus at center
		var a = orbital_distance  # semi-major axis
		var e = clamp(eccentricity, 0.0, 0.99)
		var r = a * (1.0 - e * e) / (1.0 + e * cos(orbital_angle))
		return Vector2(cos(orbital_angle), sin(orbital_angle)) * r

## Calculate the orbital velocity vector based on current angle
func calculate_orbital_velocity(speed_rad_per_sec: float = -1.0) -> Vector2:
	if speed_rad_per_sec < 0:
		speed_rad_per_sec = get_speed_radians_per_second()
	
	var velocity_magnitude: float
	
	if eccentricity == 0.0:
		# Circular orbit: constant speed
		velocity_magnitude = speed_rad_per_sec * orbital_distance
	else:
		# Elliptical orbit: velocity varies with distance (vis-viva equation)
		var a = orbital_distance
		var e = clamp(eccentricity, 0.0, 0.99)
		var r = a * (1.0 - e * e) / (1.0 + e * cos(orbital_angle))
		velocity_magnitude = speed_rad_per_sec * r
	
	# Velocity is tangential (perpendicular to radius vector)
	return Vector2(-sin(orbital_angle), cos(orbital_angle)) * velocity_magnitude

## Get current orbital distance (accounts for eccentricity)
func get_current_distance() -> float:
	if eccentricity == 0.0:
		return orbital_distance
	else:
		var a = orbital_distance
		var e = clamp(eccentricity, 0.0, 0.99)
		return a * (1.0 - e * e) / (1.0 + e * cos(orbital_angle))

## Get the global position where this orbit is centered
func get_orbital_center_global() -> Vector2:
	if orbital_body and is_instance_valid(orbital_body):
		return orbital_body.global_position
	return Vector2.ZERO

## Get full orbital velocity including parent body's velocity
func get_full_velocity() -> Vector2:
	var velocity = calculate_orbital_velocity()
	if orbital_body and is_instance_valid(orbital_body) and orbital_body is RigidBody2D:
		velocity += (orbital_body as RigidBody2D).linear_velocity
	return velocity

