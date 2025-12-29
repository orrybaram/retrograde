extends Node2D
class_name StarField

# Shader parameters - exposed for easy tweaking
@export var background_color: Color = Color(0.02, 0.04, 0.12, 1.0)
@export var aspect_ratio: float = 1.0
@export var density: float = 1.3
@export var layer_parascale: int = 4
@export var star_wave: Vector2 = Vector2(0.0, 0.0)
@export var star_size: float = 3.0
@export var star_rotate_speed: float = 0.5
@export var twinkle_effect: float = 0.6
@export var twinkle_speed: float = 0.3
@export var pixelate_enabled: bool = false
@export var pixelate_count: float = 1000.0

# Parallax settings
@export var parallax_speed_multiplier: float = 0.001  # How fast stars move relative to camera (0.001 = slow parallax)

var starfield_rect: ColorRect
var shader_material: ShaderMaterial
var camera: Camera2D = null
var ship: RigidBody2D = null

func _ready() -> void:
	# Set z_index to be behind everything
	z_index = -10
	
	# Create ColorRect to display the shader
	starfield_rect = ColorRect.new()
	starfield_rect.name = "StarfieldRect"
	starfield_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(starfield_rect)
	
	# Load shader and create material
	var shader = load("res://scenes/AnimatedStarfield.gdshader")
	if shader:
		shader_material = ShaderMaterial.new()
		shader_material.shader = shader
		starfield_rect.material = shader_material
		
		# Set initial shader parameters
		_update_shader_parameters()
	else:
		push_error("Failed to load AnimatedStarfield.gdshader")
	
	# Connect to viewport size changes
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	# Set initial size
	_on_viewport_size_changed()
	
	# Find ship and camera for positioning
	_find_ship_and_camera()

func _find_ship_and_camera() -> void:
	# Find the Ship - try multiple methods
	ship = get_node_or_null("../Ship") as RigidBody2D
	if not ship:
		# Try to find by searching the tree
		var ships = get_tree().get_nodes_in_group("ships")
		if ships.size() > 0:
			ship = ships[0] as RigidBody2D
	if not ship:
		# Try to find Ship by class name
		for child in get_tree().get_nodes_in_group("planets"):
			var parent = child.get_parent()
			if parent and parent.name == "Main":
				ship = parent.get_node_or_null("Ship") as RigidBody2D
				break
	
	if ship:
		camera = ship.get_node_or_null("Camera2D") as Camera2D

func _process(_delta: float) -> void:
	# Update ship and camera references if needed
	if not ship or not camera:
		_find_ship_and_camera()
	
	if not starfield_rect or not camera:
		return
	
	# Get ship's actual physics velocity (not input-based)
	var ship_velocity: Vector2 = Vector2.ZERO
	if ship and is_instance_valid(ship):
		ship_velocity = ship.linear_velocity
	
	# Convert ship velocity to star_speed for the shader
	# For parallax, stars should move opposite to ship movement
	# The shader multiplies star_speed by TIME, so we pass velocity scaled by multiplier
	# Invert direction so stars scroll opposite to ship movement
	var calculated_star_speed = -ship_velocity * (parallax_speed_multiplier / 200000)
	
	# Update shader parameter
	if shader_material:
		shader_material.set_shader_parameter("star_speed", calculated_star_speed)
	
	# Position ColorRect to follow camera (for infinite starfield)
	# Center the ColorRect on the camera position
	# The shader handles infinite scrolling, so we just need to keep it visible
	starfield_rect.position = camera.global_position - starfield_rect.size / 2.0

func _on_viewport_size_changed() -> void:
	if not starfield_rect:
		return
	
	var viewport = get_viewport()
	if viewport:
		var viewport_size = viewport.get_visible_rect().size
		# Make ColorRect cover the entire viewport (with some margin for camera movement)
		# Use a large size to ensure it covers all camera positions
		starfield_rect.size = viewport_size * 10.0  # Large enough to cover camera movement
		starfield_rect.position = -starfield_rect.size / 2.0
		
		# Update aspect ratio based on viewport
		if viewport_size.y > 0:
			aspect_ratio = viewport_size.x / viewport_size.y
			_update_shader_parameters()

func _update_shader_parameters() -> void:
	if not shader_material:
		return
	
	shader_material.set_shader_parameter("background_color", Vector3(background_color.r, background_color.g, background_color.b))
	shader_material.set_shader_parameter("aspect_ratio", aspect_ratio)
	shader_material.set_shader_parameter("density", density)
	shader_material.set_shader_parameter("layer_parascale", layer_parascale)
	# star_speed is now calculated dynamically in _process based on camera movement
	shader_material.set_shader_parameter("star_speed", Vector2.ZERO)  # Will be updated in _process
	shader_material.set_shader_parameter("star_wave", star_wave)
	shader_material.set_shader_parameter("star_size", star_size)
	shader_material.set_shader_parameter("star_rotate_speed", star_rotate_speed)
	shader_material.set_shader_parameter("twinkle_effect", twinkle_effect)
	shader_material.set_shader_parameter("twinkle_speed", twinkle_speed)
	shader_material.set_shader_parameter("pixelate_enabled", pixelate_enabled)
	shader_material.set_shader_parameter("pixelate_count", pixelate_count)

# Note: Shader parameters are updated in _ready() and when viewport size changes.
# To update shader parameters at runtime, modify the @export variables and call _update_shader_parameters()
