extends RigidBody2D
class_name Ship

@export var thrust_power: float = 350.0
@export var turn_speed: float = 5
@export var fuel_consumption_rate: float = 5.0  # Fuel consumed per second when thrusting
@export var boost_power_multiplier: float = 2.0  # Multiplier for boost thrust power
@export var boost_fuel_multiplier: float = 3.0  # Multiplier for boost fuel consumption

@export var max_hull: float = 100.0
@export var crash_damage_multiplier: float = 0.5  # Damage per unit of collision velocity
@export var damage_threshold: float = 50.0  # Minimum impact speed to take damage (can be upgraded)

@export var max_fuel: float = 100.0  # Maximum fuel capacity

signal fuel_changed
signal fuel_depleted

var want_turn_left := false
var want_turn_right := false
var want_thrust := false
var want_reverse_thrust := false
var want_boost := false
var gs: GameState = null
var hull_strength: float = 100.0
var fuel: float = 100.0
var last_damage_time: float = 0.0
var damage_cooldown: float = 0.1  # Minimum time between damage applications (seconds)

# Landing lock system
var landing_lock_distance: float = 5.0  # Distance threshold for landing lock (pixels above surface)

# State machine reference
@onready var state_machine: StateMachine = $"StateMachine"

@onready var thruster_particles: GPUParticles2D = $"ThrusterParticles"
@onready var boost_particles: GPUParticles2D = $"BoostParticles"
@onready var side_thruster_particles: GPUParticles2D = $"SideThrusterParticles"
@onready var ship_polygon: Polygon2D = $"Polygon2D"
@onready var camera: ShipCamera = $"Camera2D"

@export var camera_shake_intensity: float = 1.2  # How much the camera shakes
@export var camera_shake_speed: float = 25.0  # How fast the shake oscillates

var camera_shake_time: float = 0.0
var camera_base_offset: Vector2 = Vector2.ZERO

# Store original boost particle material properties for reset
var original_boost_direction: Vector3 = Vector3(-1, 0, 0)
var original_boost_spread: float = 20.0
var original_boost_velocity_min: float = 100.0
var original_boost_velocity_max: float = 250.0
var original_boost_scale_min: float = 5.0
var original_boost_scale_max: float = 10.0
var original_boost_color: Color = Color(0.71, 0.71, 0.71, 0.5568628)
var original_boost_amount: int = 100
var original_boost_lifetime: float = 1.5

func _ready() -> void:
	add_to_group("ship")
	contact_monitor = true
	max_contacts_reported = 4
	can_sleep = false  # keep body awake while testing input; turn back on later if you like
	# Try to get GameState, with fallback
	gs = get_tree().get_first_node_in_group("game_state")
	
	# Initialize hull and fuel
	hull_strength = max_hull
	fuel = max_fuel
	
	# Store initial camera offset for shake calculations
	if camera:
		camera_base_offset = camera.offset
	
	# Duplicate particle materials so we can modify them at runtime
	if thruster_particles and thruster_particles.process_material:
		thruster_particles.process_material = thruster_particles.process_material.duplicate()
	if boost_particles and boost_particles.process_material:
		boost_particles.process_material = boost_particles.process_material.duplicate()
		# Store original boost particle properties
		var boost_material = boost_particles.process_material as ParticleProcessMaterial
		if boost_material:
			original_boost_direction = boost_material.direction
			original_boost_spread = boost_material.spread
			original_boost_velocity_min = boost_material.initial_velocity_min
			original_boost_velocity_max = boost_material.initial_velocity_max
			original_boost_scale_min = boost_material.scale_min
			original_boost_scale_max = boost_material.scale_max
			original_boost_color = boost_material.color
		original_boost_amount = boost_particles.amount
		original_boost_lifetime = boost_particles.lifetime
	if side_thruster_particles and side_thruster_particles.process_material:
		side_thruster_particles.process_material = side_thruster_particles.process_material.duplicate()

func _physics_process(dt: float) -> void:
	# Delegate to current state
	if state_machine and state_machine.current_state:
		state_machine.current_state.physics_process(dt)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Delegate to current state
	if state_machine and state_machine.current_state:
		state_machine.current_state.integrate_forces(state)


func take_damage(amount: float) -> void:
	# Check if already destroyed by checking current state
	if state_machine and state_machine.current_state is DestroyedState:
		return
	
	hull_strength -= amount
	hull_strength = max(0.0, hull_strength)
	
	if hull_strength <= 0.0:
		explode()

func explode() -> void:
	# Transition to DestroyedState
	if state_machine and state_machine.has_state("DestroyedState"):
		state_machine.change_state("DestroyedState")

## Helper method to check if ship is destroyed
func is_destroyed() -> bool:
	return state_machine and state_machine.current_state is DestroyedState

## Helper method to check if ship is locked to planet
func is_locked_to_planet() -> bool:
	return state_machine and state_machine.current_state is LandedState

## Reset boost particles to original state (after explosion)
func reset_boost_particles() -> void:
	if not boost_particles or not boost_particles.process_material:
		return
	
	var boost_material = boost_particles.process_material as ParticleProcessMaterial
	if boost_material:
		boost_material.direction = original_boost_direction
		boost_material.spread = original_boost_spread
		boost_material.initial_velocity_min = original_boost_velocity_min
		boost_material.initial_velocity_max = original_boost_velocity_max
		boost_material.scale_min = original_boost_scale_min
		boost_material.scale_max = original_boost_scale_max
		boost_material.color = original_boost_color
	
	boost_particles.amount = original_boost_amount
	boost_particles.lifetime = original_boost_lifetime
	boost_particles.one_shot = false
	boost_particles.emitting = false
	boost_particles.position = Vector2(-10, 0)  # Reset position

## Consume fuel and return true if fuel was consumed
func consume_fuel(amount: float) -> bool:
	# Only consume fuel if we have fuel available
	if fuel <= 0.0:
		return false
	
	var old_fuel = fuel
	fuel = max(0.0, fuel - amount)
	fuel_changed.emit()
	
	# Emit fuel_depleted signal when fuel reaches 0
	if fuel <= 0.0 and old_fuel > 0.0:
		fuel_depleted.emit()
	
	return fuel < old_fuel  # Return true if fuel was actually consumed
