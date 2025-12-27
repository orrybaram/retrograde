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
@export var inner_radius: float = 300.0  # Minimum distance from planet center
@export var outer_radius: float = 800.0  # Maximum distance from planet center
@export var resource_density: float = 0.01  # Resources per unit of arc length (e.g., 0.01 = 1 resource per 100 units)
@export_range(0.1, 10.0) var density_gradient: float = 2.0  # Density falloff from inner to outer (1.0 = uniform, >1.0 = more near inner, <1.0 = more near outer)
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
		spawn_ring()

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
	# OrbitalRingSpawner -> Planet -> ... -> Main
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

func spawn_ring() -> void:
	# Determine which scene to use: resource_scene if set, otherwise random from scrap_scenes
	var scenes_to_use: Array[PackedScene] = []
	if resource_scene:
		# Backward compatibility: use single resource_scene if set
		scenes_to_use = [resource_scene]
	elif scrap_scenes.size() > 0:
		# Use scrap_scenes array
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
	
	# Validate radius bounds
	if inner_radius >= outer_radius:
		push_error("OrbitalRingSpawner: inner_radius must be less than outer_radius!")
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
	
	# Calculate absolute inner and outer radii (from planet center)
	var absolute_inner_radius = body_radius + inner_radius
	var absolute_outer_radius = body_radius + outer_radius
	
	# Calculate average radius for density calculation
	var average_radius = (absolute_inner_radius + absolute_outer_radius) / 2.0
	
	# Calculate total arc length (circumference at average radius)
	var total_arc_length = TAU * average_radius
	
	# Calculate number of resources based on density
	var num_resources = int(round(total_arc_length * resource_density))
	
	# Ensure at least 1 resource
	if num_resources < 1:
		num_resources = 1
	
	# Distribute resources evenly by angle
	var angle_step = TAU / num_resources
	
	# Spawn resources evenly distributed around the ring
	for i in range(num_resources):
		# Calculate angle for this resource (evenly distributed)
		var angle = i * angle_step
		
		# Randomize radius with gradient bias toward inner radius
		# Use inverse power function: radius = inner + (outer - inner) * pow(random, 1/gradient)
		# When gradient = 1.0: uniform distribution
		# When gradient > 1.0: more bias toward inner radius (higher = more bias)
		var random_value = RNG.rng.randf()
		var radius_range = absolute_outer_radius - absolute_inner_radius
		var radius = absolute_inner_radius + radius_range * pow(random_value, 1.0 / density_gradient)
		
		# Calculate position
		var resource_pos = body_pos + Vector2(cos(angle), sin(angle)) * radius
		
		# Randomly select a scrap scene from available scenes
		var selected_scene = scenes_to_use[RNG.rng.randi() % scenes_to_use.size()]
		
		# Spawn resource
		var resource = selected_scene.instantiate()
		scene_root.add_child(resource)
		resource.global_position = resource_pos
		
		# Set random rotation for visual variety
		resource.rotation = RNG.rng.randf() * TAU
		
		# Set random rotation speed (can be negative or positive)
		# Range: -2.0 to 2.0 radians per second
		var rotation_speed_range = 0.5
		resource._rotation_speed = RNG.rng.randf_range(-rotation_speed_range, rotation_speed_range)
		
		# Set random scaling (0.5 to 1.0)
		var random_scale = RNG.rng.randf_range(0.5, 1.0)
		resource.scale = Vector2(random_scale, random_scale)
		
		# Set resource to orbit around body (make it "in orbit")
		# Resources are Area2D nodes, so we simulate orbital mechanics
		if resource.has_method("start_harvest"):  # Check if it's a ResourceNode
			# Calculate initial orbital parameters
			var offset = resource_pos - body_pos
			var distance = offset.length()
			var initial_angle = atan2(offset.y, offset.x)
			
			# Calculate orbital speed based on distance (circular orbit)
			# Convert from 0-100 scale to radians per second, then scale by distance
			# Base speed: 0.1 rad/s at 100 = ~63 seconds per orbit (much more visible)
			var speed_rad_per_sec = orbital_speed / 100.0
			var distance_factor = 1000.0 / max(distance, 100.0)  # Faster closer, slower farther
			var calculated_speed_rad_per_sec = speed_rad_per_sec * distance_factor
			
			# Store orbital parameters
			# Resources can orbit planets or space stations
			if parent_planet:
				resource._orbital_planet = parent_planet
			elif parent_station:
				# For space stations, we'll use the same property name for compatibility
				# The ResourceNode will need to handle both Planet and SpaceStation
				resource._orbital_planet = orbital_body
			
			resource._offset_from_planet = offset
			resource._orbital_angle = initial_angle
			resource._orbital_distance = distance
			resource._orbital_speed = calculated_speed_rad_per_sec
			
			# Randomize resource properties
			resource.amount = RNG.rng.randi_range(5, 20)
			resource.max_amount = resource.amount
			resource.harvest_rate = RNG.rng.randf_range(3.0, 8.0)
		elif resource is RigidBody2D:
			# If it's a RigidBody2D, set velocity directly
			(resource as RigidBody2D).linear_velocity = body_velocity

