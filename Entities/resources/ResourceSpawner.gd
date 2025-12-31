extends Node2D
class_name ResourceSpawner

@export var resource_scene: PackedScene = preload("res://entities/resources/Scrap.tscn")
@export var num_clusters: int = 5  # Number of clusters around the planet
@export var min_resources_per_cluster: int = 3
@export var max_resources_per_cluster: int = 8
@export var min_distance: float = 300.0
@export var max_distance: float = 800.0
@export_range(0, 100) var orbital_speed: float = 100.0  # Orbital speed scale (0 = static, 100 = fastest)
@export var auto_spawn: bool = true

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
		# Wait a frame to ensure everything is initialized
		await get_tree().process_frame
		spawn_cluster()

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
	# ResourceSpawner -> Planet -> ... -> Main
	var current = get_parent()
	while current:
		var parent = current.get_parent()
		if parent == null or parent == get_tree().root:
			# This is the top-level node (Main)
			scene_root = current as Node2D
			return
		current = parent
	
	# Fallback: use scene root's first child
	if not scene_root:
		var root = get_tree().root
		var main = root.get_child(0) as Node2D
		if main:
			scene_root = main

func spawn_cluster() -> void:
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
	var body_velocity: Vector2
	var orbital_body: Node2D  # The body resources will orbit around
	
	if parent_planet:
		body_pos = parent_planet.global_position
		body_radius = parent_planet.radius
		body_velocity = parent_planet.linear_velocity
		orbital_body = parent_planet
	elif parent_station:
		body_pos = parent_station.global_position
		# Space stations don't have a radius property, use approximate size
		body_radius = 1200.0  # Approximate station size (moon-sized)
		body_velocity = parent_station.linear_velocity
		orbital_body = parent_station
	
	# Distribute clusters evenly around the body (360 degrees)
	var angle_step = TAU / num_clusters  # Angle between each cluster
	
	# Spawn multiple clusters around the body
	for cluster_index in range(num_clusters):
		# Calculate cluster angle - evenly distributed with some randomness
		var base_angle = cluster_index * angle_step
		var angle_variation = angle_step * 0.2  # Small variation (±20% of step)
		var cluster_angle = base_angle + RNG.rng.randf_range(-angle_variation, angle_variation)
		
		# Random distance from body surface for this cluster
		var distance_from_surface = RNG.rng.randf_range(min_distance, max_distance)
		var cluster_distance = body_radius + distance_from_surface
		
		# Cluster center position
		var cluster_center = body_pos + Vector2(cos(cluster_angle), sin(cluster_angle)) * cluster_distance
		
		# Random number of resources in this cluster
		var resources_in_cluster = RNG.rng.randi_range(min_resources_per_cluster, max_resources_per_cluster)
		
		# Spawn resources tightly grouped at cluster center
		for i in range(resources_in_cluster):
			var resource_pos: Vector2
			var attempts = 0
			var max_attempts = 10
			
			# Try to find a valid position outside the body
			while attempts < max_attempts:
				attempts += 1
				
				# Resources spawn at cluster center with tiny random offset to avoid exact overlap
				# Small offset (5-15 pixels) so they're visible but still tightly grouped
				var tiny_offset = Vector2(
					RNG.rng.randf_range(-150.0, 150.0),
					RNG.rng.randf_range(-150.0, 150.0)
				)
				resource_pos = cluster_center + tiny_offset
				
				# Calculate distance from body center
				var distance_to_body_center = resource_pos.distance_to(body_pos)
				var min_allowed_distance = body_radius + min_distance
				
				# If too close to body, push it out
				if distance_to_body_center < min_allowed_distance:
					var direction = (resource_pos - body_pos).normalized()
					# If direction is zero (exactly at body center), use cluster direction
					if direction.length() < 0.001:
						direction = Vector2(cos(cluster_angle), sin(cluster_angle))
					resource_pos = body_pos + direction * min_allowed_distance
				
				# Verify final position is outside body
				var final_distance = resource_pos.distance_to(body_pos)
				if final_distance >= body_radius + min_distance:
					break
			
			# Spawn resource
			var resource = resource_scene.instantiate()
			scene_root.add_child(resource)
			resource.global_position = resource_pos
			
			# Set resource to orbit around body (make it "in orbit")
			# Resources are Area2D nodes, so we simulate orbital mechanics
			if resource.has_method("start_harvest"):  # Check if it's a ResourceNode
				# Calculate initial orbital parameters
				var offset = resource_pos - body_pos
				var distance = offset.length()
				var initial_angle = atan2(offset.y, offset.x)
				
				# Calculate orbital speed based on distance (circular orbit)
				# Convert from 0-100 scale to radians per second, then scale by distance
				var speed_rad_per_sec = (orbital_speed / 100.0) * 0.001
				var distance_factor = 1000.0 / max(distance, 100.0)  # Faster closer, slower farther
				var calculated_speed_rad_per_sec = speed_rad_per_sec * distance_factor
				
				# Configure OrbitalMotion component directly
				if resource._orbital_motion:
					var motion = resource._orbital_motion
					motion.orbital_distance = distance
					# Convert radians/sec to 0-100 speed scale
					motion.orbital_speed = (calculated_speed_rad_per_sec / motion.speed_scale) * 100.0
					motion.initial_angle = initial_angle
					motion.initialize(orbital_body)
				
				# Randomize resource properties
				resource.amount = RNG.rng.randi_range(5, 20)
				resource.max_amount = resource.amount
				resource.harvest_rate = RNG.rng.randf_range(3.0, 8.0)
			elif resource is RigidBody2D:
				# If it's a RigidBody2D, set velocity directly
				(resource as RigidBody2D).linear_velocity = body_velocity
