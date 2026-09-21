extends RigidBody2D
class_name Ship

## Player ship entity. Owns fuel, hull (via HealthComponent), cargo weight, and
## input intent flags. Behavior is delegated to states via StateMachine:
## FlyingState → LandedState (docked) / PlanetLandedState (on a landing site) /
## HarvestingState / StrandedState / DestroyedState.
## Signals: fuel_changed, fuel_depleted, cargo_changed.

@export var thrust_power: float = 262.5
@export var turn_speed: float = 5
@export var fuel_consumption_rate: float = 5.0  # Fuel consumed per second when thrusting
@export var boost_power_multiplier: float = 2.667  # Multiplier for boost thrust power (keeps the boost at ~700)
@export var boost_fuel_multiplier: float = 3.0  # Multiplier for boost fuel consumption
## Ordinary thrust stops adding speed past this (px/s). It still steers and brakes up
## there; only the boost (or gravity) takes the ship faster. Keeps short hops around a
## debris field untouched while making the long haul between planets a slow cruise.
@export var cruise_speed: float = 300.0

@export var max_hull: float = 100.0
@export var crash_damage_multiplier: float = 0.5  # Damage per unit of collision velocity
@export var damage_threshold: float = 50.0  # Minimum impact speed to take damage (can be upgraded)

@export var max_fuel: float = 150.0  # Maximum fuel capacity

@export var max_cargo_weight: float = 50.0  # Hold space (gems take 1-3 units each)

# Base stats (stored at initialization, never modified by upgrades)
var base_max_hull: float = 100.0
var base_max_fuel: float = 150.0
var base_max_cargo_weight: float = 50.0
@export var base_mass: float = 1.0  # Base mass of the ship (set in _ready from initial mass)
@export var cargo_mass_multiplier: float = 0.01  # How much cargo weight affects physics mass

## The tip of the hull, where Freight is clamped (local space).
const NOSE := Vector2(10, 0)
## A clamped load slows turning by the ratio of the ship's own inertia to the combined
## inertia. Taken honestly that leaves a long piece all but unturnable, so the ratio is
## softened by this power: 1.0 is physical, 0.5 its square root.
const FREIGHT_TURN_EXPONENT := 0.5

## Freight clamped to the nose (docs/adr/0012), or null. See clamp_freight.
var freight: Freight = null
var _freight_collider: CollisionPolygon2D = null
var _turn_ratio := 1.0

signal fuel_changed
signal fuel_depleted
signal cargo_changed(current_weight: float, max_weight: float)

var want_turn_left := false
var want_turn_right := false
var want_thrust := false
var want_reverse_thrust := false
var want_boost := false
var gs: GameState = null
var health_component: HealthComponent
var hull_strength: float:
	get:
		return health_component.current_hp if health_component else 0.0
	set(value):
		if health_component:
			health_component.current_hp = clamp(value, 0.0, health_component.max_hp)
			# A repair, a save being restored or an upgrade all land here rather than
			# in take_damage, so this is where the readouts have to be told.
			health_component.hp_changed.emit(health_component.current_hp, health_component.max_hp)
var fuel: float = 200.0
## Dev-panel overrides (ui/DevPanel.gd), off in normal play. Nothing but that panel
## writes them, and it only exists in a debug build.
var dev_invulnerable := false
var dev_infinite_fuel := false
var low_fuel_effect: LowFuelEffect = null  # vapor + engine sputter when the tank runs low
var low_hull_effect: LowHullEffect = null  # venting smoke, sparks and a strobe when the hull fails
var sonar: SonarPulse = null
var _sonar_blocked := false  # this hold of `action` began or passed somewhere it couldn't ping  # sonar resonance rings while `action` is held (see wants_sonar)

# Landing lock system
var landing_lock_distance: float = 5.0  # Distance threshold for landing lock (pixels above surface)

# State machine reference
@onready var state_machine: StateMachine = $"StateMachine"
@onready var harvest_cone: HarvestCone = $"HarvestCone"

@onready var thruster_particles: GPUParticles2D = $"ThrusterParticles"
@onready var boost_particles: GPUParticles2D = $"BoostParticles"
@onready var side_thruster_particles: GPUParticles2D = $"SideThrusterParticles"
@onready var ship_polygon: Node2D = $"Body"
@onready var camera: ShipCamera = $"Camera2D"

@export var camera_shake_intensity: float = 1.2  # How much the camera shakes
@export var camera_shake_speed: float = 25.0  # How fast the shake oscillates
@export var damage_shake_intensity: float = 2.0  # How much the camera shakes when taking damage
@export var damage_shake_duration: float = 0.3  # How long damage shake lasts (seconds)
## Damage that counts as a full-strength hit; anything more shakes and glitches no harder.
const DAMAGE_REFERENCE := 20.0
@export var explosion_shake_intensity: float = 5.0  # How much the camera shakes on explosion
@export var explosion_shake_duration: float = 1.0  # How long explosion shake lasts (seconds)
@export var harvest_shake_intensity: float = 1.5  # How much the camera shakes on harvest success
@export var harvest_shake_duration: float = 0.5  # How long harvest shake lasts (seconds)
@export var harvest_lockon_shake_intensity: float = 0.8  # Camera bump on harvest lock-on
@export var harvest_lockon_shake_duration: float = 0.3  # Duration of lock-on bump
## Clamping Freight: the camera bump, the particle burst (x the base clunk) and the hitstop.
const CLAMP_SHAKE_INTENSITY := 1.5
const CLAMP_SHAKE_DURATION := 0.3
const CLAMP_BURST := 1.7
## How many times more particles than the burst's strength alone gives, clamping and letting go.
const CLAMP_DENSITY := 2.5
const RELEASE_DENSITY := 2.0
## How opaque the shockwave rings start.
const CLAMP_RING_ALPHA := 0.4
const CLAMP_HITSTOP := 0.04
## Letting go: a lighter version of the same, no hitstop.
const RELEASE_SHAKE_INTENSITY := 1.0
const RELEASE_SHAKE_DURATION := 0.25
const RELEASE_BURST := 1.3
## Released Freight drifts off the nose this fast (px/s) on top of the ship's velocity, so
## the two slowly part instead of hanging together.
const RELEASE_DRIFT := 6.0

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
var original_boost_color: Color = Color(Colors.CREAM_SOFT, 0.5568628)
var original_boost_amount: int = 100
var original_boost_lifetime: float = 1.5

func _ready() -> void:
	add_to_group("ship")
	z_index = 2  # over planets, stations and landing pads it sits on
	contact_monitor = true
	max_contacts_reported = 4
	can_sleep = false  # keep body awake while testing input; turn back on later if you like
	# Try to get GameState, with fallback
	gs = get_tree().get_first_node_in_group("game_state")
	
	# Store base stats from @export values (these are the unmodified base values)
	base_max_hull = max_hull
	base_max_fuel = max_fuel
	base_max_cargo_weight = max_cargo_weight

	# Create HealthComponent
	health_component = HealthComponent.new()
	health_component.name = "HealthComponent"
	health_component.max_hp = max_hull
	health_component.damage_cooldown = 0.1
	add_child(health_component)
	health_component.died.connect(explode)
	# Hull news goes out on the bus so the dashboard, the overlay and the robot can
	# each react without any of them reaching into the ship for it.
	health_component.damaged.connect(_on_damaged)
	health_component.hp_changed.connect(func(current: float, max_hp: float) -> void:
		EventBus.ship_hull_changed.emit(current, max_hp))

	# Initialize fuel
	fuel = max_fuel
	low_fuel_effect = LowFuelEffect.new()
	low_fuel_effect.name = "LowFuelEffect"
	add_child(low_fuel_effect)

	low_hull_effect = LowHullEffect.new()
	low_hull_effect.name = "LowHullEffect"
	add_child(low_hull_effect)

	sonar = SonarPulse.new()
	sonar.name = "SonarPulse"
	add_child(sonar)

	var magnet := GemMagnet.new()
	magnet.name = "GemMagnet"
	add_child(magnet)

	var scanner := PlanetScanner.new()
	scanner.name = "PlanetScanner"
	add_child(scanner)

	# Visiting a Body is not the scanner's job — it works from the first minute,
	# before the array is ever bought (docs/adr/0003).
	var planet_log := PlanetLog.new()
	planet_log.name = "PlanetLog"
	add_child(planet_log)

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

var _last_frame_usec := 0

func _process(_dt: float) -> void:
	# Hitstop slows physics, but orbits keep wall-clock time: keep pace so the ship
	# doesn't fall behind the scrap it's harvesting.
	var now := Time.get_ticks_usec()
	var real_dt := (now - _last_frame_usec) / 1_000_000.0 if _last_frame_usec > 0 else 0.0
	_last_frame_usec = now
	if real_dt < 0.1 and not is_gone():
		var catch_up := HarvestJuice.hitstop_catch_up(linear_velocity, real_dt)
		if catch_up != Vector2.ZERO:
			global_position += catch_up

func _physics_process(dt: float) -> void:
	# Delegate to current state
	if state_machine and state_machine.current_state:
		state_machine.current_state.physics_process(dt)
	if sonar:
		_drive_sonar()

## `action` held charges a ping, let go sends it. A hold that was ever somewhere a ping
## isn't allowed (docked, a menu, a load clamped - including the hold that lets the load
## go) belongs to that, not the sonar: any charge is dropped, and the rest of the hold is
## ignored until the key comes up.
func _drive_sonar() -> void:
	var down := Input.is_action_pressed("action")
	if not down:
		_sonar_blocked = false
	elif not wants_sonar():
		_sonar_blocked = true
	if down and not _sonar_blocked:
		sonar.charging = true
	elif sonar.charging:
		if down:
			sonar.cancel()
		else:
			sonar.fire()

## Sonar resonance: `action` pings from anywhere the ship is free to act. It is not tied
## to harvesting; a scrap or a seam in the rings is what makes a ping a harvest. The state
## decides (ShipState.allows_sonar), and a menu over the game takes the key.
func wants_sonar() -> bool:
	if not Input.is_action_pressed("action"):
		return false
	var state := state_machine.current_state as ShipState if state_machine else null
	if state == null or not state.allows_sonar():
		return false
	var flying := state_machine.states.get("FlyingState") as FlyingState
	return flying == null or not flying._is_ui_blocking_input()

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Delegate to current state
	if state_machine and state_machine.current_state:
		state_machine.current_state.integrate_forces(state)


func take_damage(amount: float) -> void:
	if is_gone() or dev_invulnerable:
		return
	health_component.take_damage(amount)

## The hit that actually landed — hits the damage cooldown swallowed never reach here,
## so the kick and the glitch fire once per wound instead of once per graze.
func _on_damaged(amount: float) -> void:
	var ratio := health_component.get_hp_ratio()
	# A scratch rattles the frame; a real hit throws it. Held back from the explosion
	# band so FlyingState never mistakes a bad landing for the ship coming apart.
	var severity := clampf(amount / DAMAGE_REFERENCE, 0.35, 1.0)
	if damage_shake_current_intensity < damage_shake_intensity * severity or damage_shake_time <= 0.0:
		damage_shake_time = damage_shake_duration
		damage_shake_current_intensity = damage_shake_intensity * severity
	EventBus.ship_damaged.emit(amount, ratio)

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

## Destroyed or taken by the Void: either way the hull is gone and nothing —
## damage, hitstop catch-up, harvesting — should still be acting on it.
func is_gone() -> bool:
	return state_machine and (state_machine.current_state is DestroyedState or state_machine.current_state is ConsumedState)

## Helper method to check if ship is locked to planet
func is_locked_to_planet() -> bool:
	return state_machine and state_machine.current_state is LandedState

## True while sitting on a planet's landing site.
func is_landed_on_planet() -> bool:
	return state_machine and state_machine.current_state is PlanetLandedState

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
	# The dev panel's infinite tank: the engine still fires, the gauge never moves.
	if dev_infinite_fuel:
		return true
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

## Update the ship's physics mass based on current cargo weight, plus any Freight on the nose
func update_mass_from_cargo() -> void:
	var cargo_weight = InventoryManager.get_total_weight()
	_apply_mass(base_mass + (cargo_weight * cargo_mass_multiplier))
	cargo_changed.emit(cargo_weight, max_cargo_weight)

## Set the body's mass, centre of mass and inertia from the ship's own mass and whatever
## is clamped to it. Unladen this is exactly the ship as it always was: its own mass, its
## centre at the origin, and inertia left to the engine.
func _apply_mass(own_mass: float) -> void:
	if not is_carrying():
		mass = own_mass
		center_of_mass = Vector2.ZERO
		inertia = 0.0
		_turn_ratio = 1.0
		return
	var hull := _hull_outline()
	var carried := freight.transform * freight.outline
	var carried_box := Freight.bounds(carried)
	var total := own_mass + freight.mass
	var com := carried_box.get_center() * freight.mass / total
	var own_i := Freight.box_inertia(hull, own_mass)
	var combined_i := own_i + Freight.box_inertia(carried, freight.mass) - total * com.length_squared()
	mass = total
	center_of_mass = com
	inertia = combined_i
	_turn_ratio = turn_ratio_for(own_i, combined_i)

## How much of its unladen turn a ship keeps with a load: the inertia ratio, softened.
static func turn_ratio_for(own_inertia: float, combined_inertia: float) -> float:
	if combined_inertia <= own_inertia or combined_inertia <= 0.0:
		return 1.0
	return pow(own_inertia / combined_inertia, FREIGHT_TURN_EXPONENT)

## 1.0 unladen; less with Freight clamped (FlyingState.turned_spin reads it).
func turn_ratio() -> float:
	return _turn_ratio

func is_carrying() -> bool:
	return freight != null and is_instance_valid(freight)

## Take hold of `f` at its Lug. It stops being a body of its own: it rides on the nose in
## the pose its Lug fixes, its outline becomes part of the hull, and its mass joins the
## ship's. Momentum is shared, so clamping a piece at rest drags the ship a little.
func clamp_freight(f: Freight) -> void:
	if is_carrying() or f == null or not is_instance_valid(f):
		return
	var own_mass := mass
	var shared := (linear_velocity * own_mass + f.linear_velocity * f.mass) / (own_mass + f.mass)
	var pose := Freight.clamped_pose(f.lug_position, f.lug_facing, NOSE)
	freight = f
	f.process_mode = Node.PROCESS_MODE_DISABLED  # out of the physics space while it rides
	f.reparent(self, false)
	f.transform = pose
	_freight_collider = CollisionPolygon2D.new()
	_freight_collider.name = "FreightCollision"
	_freight_collider.polygon = f.outline
	_freight_collider.transform = pose
	add_child(_freight_collider)
	update_mass_from_cargo()
	linear_velocity = shared
	_clamp_fx(f)

## Let go of whatever is clamped, where it is. It carries on as the ship was moving - the
## ship's velocity, the ship's heading, no spin - plus a nudge of RELEASE_DRIFT straight off
## the nose, so the two very slowly part. Returns the piece (null if nothing was clamped).
func release_freight() -> Freight:
	if not is_carrying():
		freight = null
		return null
	var f := freight
	var carried := global_transform * f.transform
	var hull_velocity := _velocity_at(global_position, to_global(center_of_mass))
	freight = null
	if _freight_collider:
		remove_child(_freight_collider)
		_freight_collider.queue_free()
		_freight_collider = null
	f.reparent(get_parent(), false)
	f.global_transform = carried
	f.process_mode = Node.PROCESS_MODE_INHERIT
	var forward := (to_global(NOSE) - global_position).normalized()
	f.linear_velocity = hull_velocity + forward * RELEASE_DRIFT
	f.angular_velocity = 0.0
	update_mass_from_cargo()
	linear_velocity = hull_velocity
	# It was touching the nose: let the two drift apart before they can collide again.
	f.add_collision_exception_with(self)
	_release_fx(f)
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if is_instance_valid(f):
			f.remove_collision_exception_with(self))
	return f

## Letting go: smoke and sparks where the Lug leaves the nose, one cream ring, the Lug
## glints and the piece jolts, and the camera takes a small bump.
func _release_fx(f: Freight) -> void:
	var nose := to_global(NOSE)
	ClampFX.burst(get_parent(), nose, linear_velocity, RELEASE_BURST, RELEASE_DENSITY)
	HarvestJuice.ring(get_parent(), nose, Color(Colors.CREAM, CLAMP_RING_ALPHA), 50.0, linear_velocity)
	f.punch(0.1)
	f.flash_released()
	damage_shake_time = RELEASE_SHAKE_DURATION
	damage_shake_current_intensity = RELEASE_SHAKE_INTENSITY

## Taking hold is the big moment, bigger than letting go: a beat of hitstop, two
## shockwaves off the nose, a heavier spray of sparks, a harder camera bump, and the piece
## lights up and jolts.
func _clamp_fx(f: Freight) -> void:
	var nose := to_global(NOSE)
	var world := get_parent()
	ClampFX.burst(world, nose, linear_velocity, CLAMP_BURST, CLAMP_DENSITY)
	HarvestJuice.ring(world, nose, Color(Colors.CREAM, CLAMP_RING_ALPHA), 45.0, linear_velocity)
	HarvestJuice.ring(world, nose, Color(Colors.PRIMARY, CLAMP_RING_ALPHA), 80.0, linear_velocity)
	HarvestJuice.hitstop(get_tree(), CLAMP_HITSTOP)
	f.punch(0.14)
	f.flash_clamped()
	damage_shake_time = CLAMP_SHAKE_DURATION
	damage_shake_current_intensity = CLAMP_SHAKE_INTENSITY

## Is `shape_index` (a contact's local shape) part of the clamped load rather than the hull?
func is_freight_shape(shape_index: int) -> bool:
	if _freight_collider == null or shape_index < 0:
		return false
	return shape_owner_get_owner(shape_find_owner(shape_index)) == _freight_collider

## Where the clamped load's middle is, in world space (the ship's own position if none).
func freight_center() -> Vector2:
	return freight.global_transform * freight.own_center() if is_carrying() else global_position

func _velocity_at(point: Vector2, com: Vector2) -> Vector2:
	var r := point - com
	return linear_velocity + Vector2(-angular_velocity * r.y, angular_velocity * r.x)

func _hull_outline() -> PackedVector2Array:
	var hull := get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	return hull.transform * hull.polygon if hull else PackedVector2Array([Vector2(-12, -9), Vector2(10, 9)])

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
						upgrade._apply_unlock_feature(game_state)
	
	# Update hull and fuel to match new max values
	health_component.max_hp = max_hull
	health_component.current_hp = min(health_component.current_hp, max_hull)
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

## Reset ship to initial state for a new game.
## Clears all upgrades and resets stats to base values.
func reset_to_initial_state() -> void:
	# Reset stats to base values (no upgrades)
	max_hull = base_max_hull
	max_fuel = base_max_fuel
	max_cargo_weight = base_max_cargo_weight

	# Reset current values to full
	health_component.max_hp = max_hull
	health_component.reset()
	fuel = max_fuel

	# Reset physics
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	rotation = 0.0

	# Reset camera shake
	camera_shake_time = 0.0
	damage_shake_time = 0.0
	damage_shake_current_intensity = 0.0

	# Reset boost particles
	reset_boost_particles()

	# Reset to FlyingState
	if state_machine and state_machine.has_state("FlyingState"):
		state_machine.change_state("FlyingState")

	# Ensure ship is enabled and visible
	set_process(true)
	set_physics_process(true)
	if ship_polygon:
		ship_polygon.visible = true

	# Update mass based on cargo (should be 0 after reset)
	update_mass_from_cargo()

	# Emit signals
	fuel_changed.emit()
	cargo_changed.emit(0.0, max_cargo_weight)
