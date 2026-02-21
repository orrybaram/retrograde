extends Node2D
class_name ResourceSpawner

@export var resource_scene: PackedScene = preload("res://entities/resources/Scrap.tscn")
@export var debris_scenes: Array[PackedScene] = [
	preload("res://entities/resources/Debris1.tscn"),
	preload("res://entities/resources/Debris2.tscn"),
	preload("res://entities/resources/Debris3.tscn")
]
@export var max_resources: int = 30
@export_range(0.0, 1.0) var debris_ratio: float = 0.3
@export var min_distance: float = 300.0
@export var max_distance: float = 800.0
@export_range(0, 100) var orbital_speed: float = 100.0
@export var auto_spawn: bool = true

var _spawned_nodes: Array[OrbitalNode] = []

var parent_planet: Planet = null
var parent_station: SpaceStation = null
var scene_root: Node2D = null

func _ready() -> void:
	add_to_group("resource_spawners")

	# Find parent planet or space station
	_find_parent_body()

	# Find scene root (Main) to add spawned resources to
	_find_scene_root()

	EventBus.resources_refresh_requested.connect(_on_resources_refresh_requested)

	if auto_spawn:
		# Wait for planet angles to be restored before spawning
		if EventBus.has_signal("planets_restored"):
			await EventBus.planets_restored
		else:
			await get_tree().process_frame
		spawn_resources()

func _find_parent_body() -> void:
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
	var current = get_parent()
	while current:
		var parent = current.get_parent()
		if parent == null or parent == get_tree().root:
			scene_root = current as Node2D
			return
		current = parent

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

	# Calculate counts
	var scrap_count = max_resources
	var debris_count = int(scrap_count * debris_ratio)
	var total_count = scrap_count + debris_count

	var angle_step = TAU / total_count

	# Build a shuffled list of node types, interleaving debris throughout the ring
	var node_types: Array[bool] = []
	for j in range(scrap_count):
		node_types.append(false)
	for j in range(debris_count):
		node_types.append(true)

	# Shuffle to interleave debris and scrap evenly
	for j in range(node_types.size() - 1, 0, -1):
		var k = RNG.rng.randi() % (j + 1)
		var tmp = node_types[j]
		node_types[j] = node_types[k]
		node_types[k] = tmp

	for i in range(total_count):
		var is_debris = node_types[i]

		# Calculate angle with small random variation
		var base_angle = i * angle_step
		var angle_variation = angle_step * 0.3
		var resource_angle = base_angle + RNG.rng.randf_range(-angle_variation, angle_variation)

		# Random distance from body surface
		var distance_from_surface = RNG.rng.randf_range(min_distance, max_distance)
		var distance = body_radius + distance_from_surface

		var node_pos = body_pos + Vector2(cos(resource_angle), sin(resource_angle)) * distance

		# Get node from pool
		var node: OrbitalNode
		if is_debris:
			var debris_variants = ["Debris1", "Debris2", "Debris3"]
			var variant_name = debris_variants[RNG.rng.randi() % debris_variants.size()]
			node = ResourceNodePool.get_instance(variant_name, scene_root)
		else:
			var variant_name = resource_scene.resource_path.get_file().get_basename()
			node = ResourceNodePool.get_instance(variant_name, scene_root)

		if not node:
			push_warning("Failed to get node from pool")
			continue

		node.global_position = node_pos

		_spawned_nodes.append(node)

		# Configure orbital motion
		if node._orbital_motion:
			var motion = node._orbital_motion
			motion.orbital_distance = distance

			var speed_rad_per_sec = (orbital_speed / 100.0) * 0.001
			var distance_factor = 1000.0 / max(distance, 100.0)
			var calculated_speed_rad_per_sec = speed_rad_per_sec * distance_factor

			motion.orbital_speed = (calculated_speed_rad_per_sec / motion.speed_scale) * 100.0
			motion.initial_angle = resource_angle
			motion.initialize(orbital_body)

		# Set random scaling - debris is bigger
		if is_debris:
			var random_scale = RNG.rng.randf_range(0.5, 1.0)
			node.scale = Vector2(random_scale, random_scale)

		# Set scrap-specific properties
		if node is ScrapNode:
			var scrap = node as ScrapNode
			scrap.amount = 1
			scrap.max_amount = 1
			scrap.harvest_rate = RNG.rng.randf_range(3.0, 8.0)

			if not scrap.resource_depleted.is_connected(_on_resource_depleted):
				scrap.resource_depleted.connect(_on_resource_depleted.bind(scrap))

		node._update_visual()

func _on_resources_refresh_requested() -> void:
	# Clean up invalid references
	_spawned_nodes = _spawned_nodes.filter(func(n): return is_instance_valid(n))

	var total_max = max_resources + int(max_resources * debris_ratio)
	var to_spawn = total_max - _spawned_nodes.size()
	if to_spawn <= 0:
		return

	if not resource_scene or not scene_root:
		return
	if not parent_planet and not parent_station:
		return

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

	var debris_count = int(to_spawn * debris_ratio)
	var scrap_count = to_spawn - debris_count

	var node_types: Array[bool] = []
	for j in range(scrap_count):
		node_types.append(false)
	for j in range(debris_count):
		node_types.append(true)

	for j in range(node_types.size() - 1, 0, -1):
		var k = RNG.rng.randi() % (j + 1)
		var tmp = node_types[j]
		node_types[j] = node_types[k]
		node_types[k] = tmp

	var angle_step = TAU / to_spawn
	var angle_offset = RNG.rng.randf() * TAU
	for i in range(to_spawn):
		var is_debris = node_types[i]

		var base_angle = angle_offset + i * angle_step
		var angle_variation = angle_step * 0.3
		var resource_angle = base_angle + RNG.rng.randf_range(-angle_variation, angle_variation)

		var distance_from_surface = RNG.rng.randf_range(min_distance, max_distance)
		var distance = body_radius + distance_from_surface
		var node_pos = body_pos + Vector2(cos(resource_angle), sin(resource_angle)) * distance

		var node: OrbitalNode
		if is_debris:
			var debris_variants = ["Debris1", "Debris2", "Debris3"]
			var variant_name = debris_variants[RNG.rng.randi() % debris_variants.size()]
			node = ResourceNodePool.get_instance(variant_name, scene_root)
		else:
			var variant_name = resource_scene.resource_path.get_file().get_basename()
			node = ResourceNodePool.get_instance(variant_name, scene_root)

		if not node:
			continue

		node.global_position = node_pos
		_spawned_nodes.append(node)

		if node._orbital_motion:
			var motion = node._orbital_motion
			motion.orbital_distance = distance
			var speed_rad_per_sec = (orbital_speed / 100.0) * 0.001
			var distance_factor = 1000.0 / max(distance, 100.0)
			var calculated_speed_rad_per_sec = speed_rad_per_sec * distance_factor
			motion.orbital_speed = (calculated_speed_rad_per_sec / motion.speed_scale) * 100.0
			motion.initial_angle = resource_angle
			motion.initialize(orbital_body)

		if is_debris:
			var random_scale = RNG.rng.randf_range(0.5, 1.0)
			node.scale = Vector2(random_scale, random_scale)

		if node is ScrapNode:
			var scrap = node as ScrapNode
			scrap.amount = 1
			scrap.max_amount = 1
			scrap.harvest_rate = RNG.rng.randf_range(3.0, 8.0)
			if not scrap.resource_depleted.is_connected(_on_resource_depleted):
				scrap.resource_depleted.connect(_on_resource_depleted.bind(scrap))

		node._update_visual()

func _on_resource_depleted(resource: ScrapNode) -> void:
	_spawned_nodes.erase(resource)
