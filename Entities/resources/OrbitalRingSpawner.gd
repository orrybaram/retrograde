extends Node2D
class_name OrbitalRingSpawner

@export var resource_scene: PackedScene  # Optional: single resource scene (for backward compatibility)
@export var scrap_scenes: Array[PackedScene] = [
	preload("res://entities/resources/Scrap1.tscn"),
	preload("res://entities/resources/Scrap2.tscn"),
	preload("res://entities/resources/Scrap3.tscn"),
	preload("res://entities/resources/Scrap4.tscn"),
	preload("res://entities/resources/Scrap5.tscn")
]
@export var max_resources: int = 50  # Fixed number of resources to spawn
@export var inner_radius: float = 300.0  # Minimum distance from planet center
@export var outer_radius: float = 800.0  # Maximum distance from planet center
@export_range(0.1, 10.0) var density_gradient: float = 2.0  # Radius distribution (>1.0 = more near inner)
@export_range(0, 100) var orbital_speed: float = 100.0  # Orbital speed scale (0 = static, 100 = fastest)
@export var auto_spawn: bool = true
@export var spawn_batch_size: int = 50  # Resources to spawn per frame

var remaining_resources: int = 0  # Tracks how many resources are left (persisted)
var spawner_key: String = ""  # Unique key for save/load identification
var _spawned_resources: Array[ResourceNode] = []  # Track spawned resources

var parent_planet: Planet = null
var parent_station: SpaceStation = null
var scene_root: Node2D = null

# Minimap integration - single target for entire ring
var _minimap_target: ResourceRingMinimapTarget = null

func _ready() -> void:
	add_to_group("resource_spawners")

	# Generate unique key for persistence
	spawner_key = _generate_spawner_key()

	# Initialize remaining resources to max if not set by save system
	if remaining_resources == 0:
		remaining_resources = max_resources

	# Find parent planet or space station
	_find_parent_body()

	# Find scene root (Main) to add spawned resources to
	_find_scene_root()

	if auto_spawn:
		# Register as pending spawner
		EventBus.register_pending_spawner(spawner_key)

		# Wait for planet angles to be restored before spawning
		# This ensures resources spawn at the correct orbital position
		if EventBus.has_signal("planets_restored"):
			await EventBus.planets_restored
		else:
			# Fallback: wait a frame if signal doesn't exist (new game)
			await get_tree().process_frame
		await spawn_ring()

		# Mark spawning as complete
		EventBus.mark_spawner_finished(spawner_key)

func _generate_spawner_key() -> String:
	var parts: Array[String] = [name]
	var current = get_parent()
	while current:
		if current is Planet:
			parts.push_front(current.name)
		elif current is SpaceStation:
			parts.push_front(current.name)
			break
		current = current.get_parent()
	return "/".join(parts)

func get_spawner_key() -> String:
	return spawner_key

func set_remaining_resources(count: int) -> void:
	remaining_resources = count

func _find_parent_body() -> void:
	# Traverse up the tree to find Planet or SpaceStation parent
	var current = get_parent()
	while current:
		if current is Planet:
			parent_planet = current as Planet
			return
		elif current is SpaceStation:
			parent_station = current as SpaceStation
			return
		current = current.get_parent()

func _find_scene_root() -> void:
	# Find the root Node2D (Main scene) by traversing up the tree
	var current = get_parent()
	while current:
		var parent = current.get_parent()
		if parent == null or parent == get_tree().root:
			scene_root = current as Node2D
			return
		current = parent

	# Fallback: use scene root's first child
	if not scene_root:
		var root = get_tree().root
		var main = root.get_child(0) as Node2D
		if main:
			scene_root = main

func spawn_ring() -> void:
	# Determine which scene to use
	var scenes_to_use: Array[PackedScene] = []
	if resource_scene:
		scenes_to_use = [resource_scene]
	elif scrap_scenes.size() > 0:
		scenes_to_use = scrap_scenes
	else:
		push_error("No resource scenes configured in OrbitalRingSpawner!")
		return

	if not parent_planet and not parent_station:
		push_error("OrbitalRingSpawner must be a child of a Planet or SpaceStation!")
		return

	if not scene_root:
		push_error("Could not find scene root to spawn resources!")
		return

	if inner_radius >= outer_radius:
		push_error("OrbitalRingSpawner: inner_radius must be less than outer_radius!")
		return

	if remaining_resources <= 0:
		return  # No resources left to spawn

	# Get position, radius from parent body
	var body_pos: Vector2
	var body_radius: float
	var orbital_body: Node2D

	if parent_planet:
		body_pos = parent_planet.global_position
		body_radius = parent_planet.radius
		orbital_body = parent_planet
	elif parent_station:
		body_pos = parent_station.global_position
		body_radius = 1200.0
		orbital_body = parent_station

	# Calculate absolute inner and outer radii (from planet center)
	var absolute_inner_radius = body_radius + inner_radius
	var absolute_outer_radius = body_radius + outer_radius

	# Register with minimap as a single ring target (instead of individual resources)
	_register_with_minimap(orbital_body, body_radius)

	# Distribute resources evenly by angle
	var angle_step = TAU / remaining_resources

	# Spawn resources in batches across multiple frames
	var spawned_count = 0
	while spawned_count < remaining_resources:
		var batch_end = min(spawned_count + spawn_batch_size, remaining_resources)

		for i in range(spawned_count, batch_end):
			_spawn_single_resource(i, angle_step, absolute_inner_radius, absolute_outer_radius,
				body_pos, scenes_to_use, orbital_body)

		spawned_count = batch_end

		if spawned_count < remaining_resources:
			await get_tree().process_frame

func _spawn_single_resource(i: int, angle_step: float, absolute_inner_radius: float,
		absolute_outer_radius: float, body_pos: Vector2,
		scenes_to_use: Array[PackedScene], orbital_body: Node2D) -> void:
	# Calculate angle for this resource (evenly distributed)
	var angle = i * angle_step

	# Randomize radius with gradient bias toward inner radius
	var random_value = RNG.rng.randf()
	var radius_range = absolute_outer_radius - absolute_inner_radius
	var radius = absolute_inner_radius + radius_range * pow(random_value, 1.0 / density_gradient)

	# Calculate position
	var resource_pos = body_pos + Vector2(cos(angle), sin(angle)) * radius

	# Randomly select a scrap scene from available scenes
	var selected_scene = scenes_to_use[RNG.rng.randi() % scenes_to_use.size()]

	# Spawn resource from pool
	var variant_name = selected_scene.resource_path.get_file().get_basename()
	var resource = ResourceNodePool.get_instance(variant_name, scene_root)
	if not resource:
		push_warning("Failed to get resource from pool for variant: ", variant_name)
		return

	resource.global_position = resource_pos
	resource.spawner_key = spawner_key
	resource.skip_minimap_registration = true  # Spawner handles minimap

	# Connect to track when resource is depleted
	if not resource.resource_depleted.is_connected(_on_resource_depleted):
		resource.resource_depleted.connect(_on_resource_depleted.bind(resource))

	_spawned_resources.append(resource)

	# Set random rotation for visual variety
	resource.rotation = RNG.rng.randf() * TAU

	# Set random rotation speed (can be negative or positive)
	var rotation_speed_range = 0.5
	resource._rotation_speed = RNG.rng.randf_range(-rotation_speed_range, rotation_speed_range)

	# Set random scaling (0.5 to 1.0)
	var random_scale = RNG.rng.randf_range(0.5, 1.0)
	resource.scale = Vector2(random_scale, random_scale)

	# Configure orbital motion
	if resource._orbital_motion:
		var motion = resource._orbital_motion
		motion.orbital_distance = radius

		# Calculate orbital speed based on distance
		var speed_rad_per_sec = orbital_speed / 100.0
		var distance_factor = 1000.0 / max(radius, 100.0)
		var calculated_speed_rad_per_sec = speed_rad_per_sec * distance_factor

		motion.orbital_speed = (calculated_speed_rad_per_sec / motion.speed_scale) * 100.0
		motion.initial_angle = angle
		motion.initialize(orbital_body)

	# Randomize resource properties
	resource.amount = RNG.rng.randi_range(5, 20)
	resource.max_amount = resource.amount
	resource.harvest_rate = RNG.rng.randf_range(3.0, 8.0)

	# Update visual to reflect new amount (must be after setting amount/max_amount)
	resource._update_visual()

func _on_resource_depleted(resource: ResourceNode) -> void:
	remaining_resources -= 1
	_spawned_resources.erase(resource)

func _register_with_minimap(orbital_body: Node2D, body_radius: float) -> void:
	var minimap = Minimap.get_instance(get_tree())
	if minimap and not _minimap_target:
		_minimap_target = ResourceRingMinimapTarget.new(self, orbital_body, body_radius, inner_radius, outer_radius)
		minimap.register_target(_minimap_target)

func _exit_tree() -> void:
	# Unregister from minimap
	if _minimap_target:
		var minimap = Minimap.get_instance(get_tree())
		if minimap:
			minimap.unregister_target(_minimap_target)
		_minimap_target = null
