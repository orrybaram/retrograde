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

@export var max_cargo_weight: float = 50.0  # Maximum cargo weight capacity

# Base stats (stored at initialization, never modified by upgrades)
var base_max_hull: float = 100.0
var base_max_fuel: float = 100.0
var base_max_cargo_weight: float = 50.0
@export var base_mass: float = 1.0  # Base mass of the ship (set in _ready from initial mass)
@export var cargo_mass_multiplier: float = 0.01  # How much cargo weight affects physics mass

signal fuel_changed
signal fuel_depleted
signal cargo_changed(current_weight: float, max_weight: float)

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
@onready var ship_polygon: Node2D = $"Body"
@onready var camera: ShipCamera = $"Camera2D"

@export var camera_shake_intensity: float = 1.2  # How much the camera shakes
@export var camera_shake_speed: float = 25.0  # How fast the shake oscillates
@export var damage_shake_intensity: float = 2.0  # How much the camera shakes when taking damage
@export var damage_shake_duration: float = 0.3  # How long damage shake lasts (seconds)
@export var explosion_shake_intensity: float = 5.0  # How much the camera shakes on explosion
@export var explosion_shake_duration: float = 1.0  # How long explosion shake lasts (seconds)

var camera_shake_time: float = 0.0
var damage_shake_time: float = 0.0  # Time remaining for damage shake
var damage_shake_current_intensity: float = 0.0  # Current intensity (can be overridden for explosions)
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
	
	# Store base stats from @export values (these are the unmodified base values)
	base_max_hull = max_hull
	base_max_fuel = max_fuel
	base_max_cargo_weight = max_cargo_weight
	
	# Initialize hull and fuel
	hull_strength = max_hull
	fuel = max_fuel
	
	# Store initial mass as base_mass for cargo calculations
	base_mass = mass
	
	# Connect to InventoryManager for cargo weight changes
	InventoryManager.cargo_weight_changed.connect(_on_cargo_weight_changed)
	update_mass_from_cargo()
	
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
	
	# Trigger camera shake on damage
	damage_shake_time = damage_shake_duration
	damage_shake_current_intensity = damage_shake_intensity
	
	if hull_strength <= 0.0:
		explode()

func explode() -> void:
	# Trigger intense camera shake on explosion
	damage_shake_time = explosion_shake_duration
	damage_shake_current_intensity = explosion_shake_intensity
	
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

## Update the ship's physics mass based on current cargo weight
func update_mass_from_cargo() -> void:
	var cargo_weight = InventoryManager.get_total_weight()
	mass = base_mass + (cargo_weight * cargo_mass_multiplier)
	cargo_changed.emit(cargo_weight, max_cargo_weight)

## Callback when cargo weight changes in InventoryManager
func _on_cargo_weight_changed(_total_weight: float) -> void:
	update_mass_from_cargo()

## Get current cargo weight
func get_cargo_weight() -> float:
	return InventoryManager.get_total_weight()

## Check if cargo is at capacity
func is_cargo_full() -> bool:
	return InventoryManager.get_total_weight() >= max_cargo_weight

## Reapply all upgrades based on upgrade levels in GameState.
## This ensures upgrades persist through load/respawn.
func reapply_all_upgrades(game_state: GameState) -> void:
	if not game_state:
		return
	
	# Reset ship stats to base values
	max_hull = base_max_hull
	max_fuel = base_max_fuel
	max_cargo_weight = base_max_cargo_weight
	
	# Get the scene tree to search for stores
	var tree = get_tree()
	if not tree:
		return
	
	# Iterate through all upgrade paths and reapply upgrades in tier order
	for upgrade_path in game_state.upgrade_levels.keys():
		var current_tier = game_state.get_upgrade_level(upgrade_path)
		
		# Apply all upgrades up to and including current tier
		for tier in range(1, current_tier + 1):
			var upgrade = UpgradeItem.find_upgrade_by_path_and_tier(tree, upgrade_path, tier)
			if upgrade:
				# Apply the upgrade effect without updating upgrade_levels (already set)
				match upgrade.effect_type:
					UpgradeItem.EffectType.ADD_STAT:
						_apply_add_stat_from_upgrade(upgrade)
					UpgradeItem.EffectType.MULTIPLY_STAT:
						_apply_multiply_stat_from_upgrade(upgrade)
					UpgradeItem.EffectType.UNLOCK_FEATURE:
						# Unlock features are handled in GameState, skip here
						pass
	
	# Update hull and fuel to match new max values
	hull_strength = min(hull_strength, max_hull)
	fuel = min(fuel, max_fuel)
	
	# Update cargo signal
	cargo_changed.emit(get_cargo_weight(), max_cargo_weight)

## Helper to apply ADD_STAT upgrade effect (without updating GameState)
func _apply_add_stat_from_upgrade(upgrade: UpgradeItem) -> void:
	match upgrade.effect_target:
		"max_hull":
			max_hull += int(upgrade.effect_value)
		"max_fuel":
			max_fuel += upgrade.effect_value
		"max_cargo_weight":
			max_cargo_weight += upgrade.effect_value
		_:
			push_warning("Ship: Unknown ADD_STAT target: %s" % upgrade.effect_target)

## Helper to apply MULTIPLY_STAT upgrade effect (without updating GameState)
func _apply_multiply_stat_from_upgrade(upgrade: UpgradeItem) -> void:
	match upgrade.effect_target:
		"max_hull":
			max_hull = int(max_hull * upgrade.effect_value)
		"max_fuel":
			max_fuel *= upgrade.effect_value
		"max_cargo_weight":
			max_cargo_weight *= upgrade.effect_value
		_:
			push_warning("Ship: Unknown MULTIPLY_STAT target: %s" % upgrade.effect_target)
