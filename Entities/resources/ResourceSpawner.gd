extends Node2D
class_name ResourceSpawner

@export var resource_scene: PackedScene = preload("res://entities/resources/Scrap.tscn")
@export var max_resources: int = 30  # Fixed number of resources to spawn
@export var min_distance: float = 300.0
@export var max_distance: float = 800.0
@export_range(0, 100) var orbital_speed: float = 100.0  # Orbital speed scale (0 = static, 100 = fastest)
@export var auto_spawn: bool = true

var remaining_resources: int = 0  # Tracks how many resources are left (persisted)
var spawner_key: String = ""  # Unique key for save/load identification
var _spawned_resources: Array[ResourceNode] = []  # Track spawned resources

var parent_planet: Planet = null
var parent_station: SpaceStation = null
var scene_root: Node2D = null

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
		# Wait for planet angles to be restored before spawning
		# This ensures resources spawn at the correct orbital position
		if EventBus.has_signal("planets_restored"):
			await EventBus.planets_restored
		else:
			# Fallback: wait a frame if signal doesn't exist (new game)
			await get_tree().process_frame
		spawn_resources()

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

func spawn_resources() -> void:
	if not resource_scene:
		push_error("Resource scene not loaded in ResourceSpawner!")
		return

	if not parent_planet and not parent_station:
		push_error("ResourceSpawner must be a child of a Planet or SpaceStation!")
		return

	if not scene_root:
		push_error("Could not find scene root to spawn resources!")
		return

	if remaining_resources <= 0:
		return  # No resources left to spawn

	# Get position, radius, and velocity from parent body
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

	# Spawn resources evenly distributed around the body
	var angle_step = TAU / remaining_resources

	for i in range(remaining_resources):
		# Calculate angle with small random variation
		var base_angle = i * angle_step
		var angle_variation = angle_step * 0.3
		var resource_angle = base_angle + RNG.rng.randf_range(-angle_variation, angle_variation)

		# Random distance from body surface
		var distance_from_surface = RNG.rng.randf_range(min_distance, max_distance)
		var distance = body_radius + distance_from_surface

		# Calculate position
		var resource_pos = body_pos + Vector2(cos(resource_angle), sin(resource_angle)) * distance

		# Spawn resource from pool
		var variant_name = resource_scene.resource_path.get_file().get_basename()
		var resource = ResourceNodePool.get_instance(variant_name, scene_root)
		if not resource:
			push_warning("Failed to get resource from pool")
			continue

		resource.global_position = resource_pos
		resource.spawner_key = spawner_key

		# Connect to track when resource is depleted
		if not resource.resource_depleted.is_connected(_on_resource_depleted):
			resource.resource_depleted.connect(_on_resource_depleted.bind(resource))

		_spawned_resources.append(resource)

		# Configure orbital motion
		if resource._orbital_motion:
			var motion = resource._orbital_motion
			motion.orbital_distance = distance

			# Calculate orbital speed based on distance
			var speed_rad_per_sec = (orbital_speed / 100.0) * 0.001
			var distance_factor = 1000.0 / max(distance, 100.0)
			var calculated_speed_rad_per_sec = speed_rad_per_sec * distance_factor

			motion.orbital_speed = (calculated_speed_rad_per_sec / motion.speed_scale) * 100.0
			motion.initial_angle = resource_angle
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
