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
@export var debris_scenes: Array[PackedScene] = [
	preload("res://entities/resources/Debris1.tscn"),
	preload("res://entities/resources/Debris2.tscn"),
	preload("res://entities/resources/Debris3.tscn")
]
@export var max_resources: int = 50  # Number of scrap nodes to spawn
@export_range(0.0, 1.0) var debris_ratio: float = 0.3  # Ratio of debris to scrap
@export var inner_radius: float = 300.0
@export var outer_radius: float = 800.0
@export_range(0.1, 10.0) var density_gradient: float = 2.0
@export_range(0, 100) var orbital_speed: float = 100.0
@export var auto_spawn: bool = true
@export var spawn_batch_size: int = 50

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

	if auto_spawn:
		# Connect to planets_restored signal for load game support
		if EventBus.has_signal("planets_restored"):
			EventBus.planets_restored.connect(_on_planets_restored)

		# Wait for planet angles to be restored before spawning
		if EventBus.has_signal("planets_restored"):
			await EventBus.planets_restored
		else:
			await get_tree().process_frame
		await spawn_ring()

func _on_planets_restored() -> void:
	# Called when loading a saved game - despawn old resources and spawn new ones
	if _spawned_nodes.is_empty():
		return

	# Despawn existing nodes
	for node in _spawned_nodes:
		if is_instance_valid(node):
			ResourceNodePool.return_instance(node)
	_spawned_nodes.clear()

	# Respawn ring
	await spawn_ring()

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

func spawn_ring() -> void:
	# Determine scrap scenes
	var scrap_scenes_to_use: Array[PackedScene] = []
	if resource_scene:
		scrap_scenes_to_use = [resource_scene]
	elif scrap_scenes.size() > 0:
		scrap_scenes_to_use = scrap_scenes
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

	# Calculate absolute inner and outer radii
	var absolute_inner_radius = body_radius + inner_radius
	var absolute_outer_radius = body_radius + outer_radius

	# Calculate counts - debris_ratio controls what fraction of total nodes are debris
	var total_count = max_resources
	var debris_count = int(total_count * debris_ratio)
	var scrap_count = total_count - debris_count

	# Distribute all nodes evenly by angle
	var angle_step = TAU / total_count

	# Build a shuffled list of node types, interleaving debris throughout the ring
	var node_types: Array[bool] = []  # true = debris, false = scrap
	for j in range(scrap_count):
		node_types.append(false)
	for j in range(debris_count):
		node_types.append(true)

	# Shuffle to interleave debris and scrap evenly around the ring
	for j in range(node_types.size() - 1, 0, -1):
		var k = RNG.rng.randi() % (j + 1)
		var tmp = node_types[j]
		node_types[j] = node_types[k]
		node_types[k] = tmp

	# Spawn in batches
	var spawned_count = 0
	while spawned_count < total_count:
		var batch_end = min(spawned_count + spawn_batch_size, total_count)

		for i in range(spawned_count, batch_end):
			var is_debris = node_types[i]
			_spawn_single_node(i, angle_step, absolute_inner_radius, absolute_outer_radius,
				body_pos, scrap_scenes_to_use, orbital_body, is_debris)

		spawned_count = batch_end

		if spawned_count < total_count:
			await get_tree().process_frame

func _spawn_single_node(i: int, angle_step: float, absolute_inner_radius: float,
		absolute_outer_radius: float, body_pos: Vector2,
		scrap_scenes_to_use: Array[PackedScene], orbital_body: Node2D, is_debris: bool) -> void:
	var angle = i * angle_step

	# Randomize radius with gradient bias toward inner radius
	var random_value = RNG.rng.randf()
	var radius_range = absolute_outer_radius - absolute_inner_radius
	var radius = absolute_inner_radius + radius_range * pow(random_value, 1.0 / density_gradient)

	var node_pos = body_pos + Vector2(cos(angle), sin(angle)) * radius

	var node: OrbitalNode
	if is_debris:
		var debris_variants = ["Debris1", "Debris2", "Debris3"]
		var variant_name = debris_variants[RNG.rng.randi() % debris_variants.size()]
		node = ResourceNodePool.get_instance(variant_name, scene_root)
	else:
		var selected_scene = scrap_scenes_to_use[RNG.rng.randi() % scrap_scenes_to_use.size()]
		var variant_name = selected_scene.resource_path.get_file().get_basename()
		node = ResourceNodePool.get_instance(variant_name, scene_root)

	if not node:
		push_warning("Failed to get node from pool")
		return

	node.global_position = node_pos

	_spawned_nodes.append(node)

	# Set random rotation for visual variety
	node.rotation = RNG.rng.randf() * TAU

	# Set random rotation speed
	var rotation_speed_range = 0.5
	node._rotation_speed = RNG.rng.randf_range(-rotation_speed_range, rotation_speed_range)

	# Set random scaling - debris is bigger
	var random_scale: float
	if is_debris:
		random_scale = RNG.rng.randf_range(0.5, 1.0)
	else:
		random_scale = RNG.rng.randf_range(0.5, 1.0)
	node.scale = Vector2(random_scale, random_scale)

	# Configure orbital motion
	if node._orbital_motion:
		var motion = node._orbital_motion
		motion.orbital_distance = radius

		var speed_rad_per_sec = orbital_speed / 100.0
		var distance_factor = 1000.0 / max(radius, 100.0)
		var calculated_speed_rad_per_sec = speed_rad_per_sec * distance_factor

		motion.orbital_speed = (calculated_speed_rad_per_sec / motion.speed_scale) * 100.0
		motion.initial_angle = angle
		motion.initialize(orbital_body)

	# Set scrap-specific properties
	if node is ScrapNode:
		var scrap = node as ScrapNode
		scrap.amount = RNG.rng.randi_range(5, 20)
		scrap.max_amount = scrap.amount
		scrap.harvest_rate = RNG.rng.randf_range(3.0, 8.0)

		# Connect depletion signal for scrap only
		if not scrap.resource_depleted.is_connected(_on_resource_depleted):
			scrap.resource_depleted.connect(_on_resource_depleted.bind(scrap))

	# Update visual
	node._update_visual()

func _on_resource_depleted(resource: ScrapNode) -> void:
	_spawned_nodes.erase(resource)
