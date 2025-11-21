extends Node2D
class_name StarField

# Star generation parameters
@export var star_count: int = 1000
var near_star_count: int = int(star_count * 0.3)
var far_star_count: int = int(star_count * 0.7)


# Parallax parameters
@export var near_parallax_speed: float = 0.002
@export var far_parallax_speed: float = 0.001

# Star appearance
@export var star_size_min: float = 1.0
@export var star_size_max: float = 3.0
@export var twinkle_speed: float = 2.0
@export var twinkle_amount: float = 0.3

# Star colors (white, blue, yellow)
@export var star_colors: Array[Color] = [
	Color(1.0, 1.0, 1.0, 1.0),  # White
	Color(0.7, 0.8, 1.0, 1.0),  # Blue
	Color(1.0, 1.0, 0.8, 1.0)   # Yellow
]

# Star field area (large enough to cover camera movement)
@export var field_size: Vector2 = Vector2(20000, 20000)
@export var cull_margin: float = 2000.0  # Extra margin around camera for culling

# Star data structure
class StarData:
	var position: Vector2
	var size: float
	var color: Color
	var twinkle_offset: float
	
	func _init(pos: Vector2, sz: float, col: Color, offset: float):
		position = pos
		size = sz
		color = col
		twinkle_offset = offset

# Star storage - organized by grid cells for efficient culling
var star_cache: Dictionary = {}  # Key: "x_y_layer", Value: Array[StarData]
var visible_near_stars: Array[StarData] = []
var visible_far_stars: Array[StarData] = []
var camera: Camera2D = null
var last_cull_bounds: Rect2 = Rect2()
var cell_size: float = 2000.0  # Size of each cache cell

func _ready() -> void:
	# Find camera (from Ship)
	_find_camera()
	# Set z_index to be behind everything
	z_index = -10
	
	# Calculate star counts
	near_star_count = int(star_count * 0.3)
	far_star_count = int(star_count * 0.7)

func _find_camera() -> void:
	# Find the Ship's camera - try multiple methods
	var ship = get_node_or_null("../Ship")
	if not ship:
		# Try to find by searching the tree
		ship = get_tree().get_first_node_in_group("ships")
	if not ship:
		# Try to find Ship by class name
		for child in get_tree().get_nodes_in_group("planets"):
			var parent = child.get_parent()
			if parent and parent.name == "Main":
				ship = parent.get_node_or_null("Ship")
				break
	
	if ship:
		camera = ship.get_node_or_null("Camera2D") as Camera2D

func _get_cell_key(cell_x: int, cell_y: int, layer: String) -> String:
	return str(cell_x) + "_" + str(cell_y) + "_" + layer

func _generate_stars_for_cell(cell_x: int, cell_y: int, layer: String, count: int) -> Array[StarData]:
	var key = _get_cell_key(cell_x, cell_y, layer)
	
	# Check cache first
	if star_cache.has(key):
		return star_cache[key]
	
	# Generate stars for this cell using seeded RNG from global singleton
	# Create unique seed offset for this cell
	var cell_seed_offset = hash(Vector2i(cell_x, cell_y)) + hash(layer)
	var rng = RNG.get_seeded_rng(cell_seed_offset)
	
	var stars: Array[StarData] = []
	var cell_min_x = cell_x * cell_size - field_size.x / 2
	var cell_max_x = (cell_x + 1) * cell_size - field_size.x / 2
	var cell_min_y = cell_y * cell_size - field_size.y / 2
	var cell_max_y = (cell_y + 1) * cell_size - field_size.y / 2
	
	for i in range(count):
		var pos = Vector2(
			rng.randf_range(cell_min_x, cell_max_x),
			rng.randf_range(cell_min_y, cell_max_y)
		)
		var size = rng.randf_range(star_size_min, star_size_max)
		var color = star_colors[rng.randi() % star_colors.size()]
		var twinkle_offset = rng.randf_range(0.0, TAU)
		stars.append(StarData.new(pos, size, color, twinkle_offset))
	
	# Cache the stars
	star_cache[key] = stars
	return stars

func _update_visible_stars(camera_pos: Vector2, viewport_size: Vector2) -> void:
	# Calculate viewport bounds with margin
	var viewport_half = viewport_size / 2.0
	var bounds = Rect2(
		camera_pos.x - viewport_half.x - cull_margin,
		camera_pos.y - viewport_half.y - cull_margin,
		viewport_size.x + cull_margin * 2.0,
		viewport_size.y + cull_margin * 2.0
	)
	
	# Only recalculate if camera moved significantly
	if bounds.intersects(last_cull_bounds) and last_cull_bounds.get_area() > 0:
		# Check if we need to update (camera moved outside previous bounds)
		if last_cull_bounds.encloses(bounds):
			return  # Still within previous bounds, no update needed
	
	last_cull_bounds = bounds
	
	# Calculate which cells we need
	var min_cell_x = int((bounds.position.x + field_size.x / 2) / cell_size)
	var max_cell_x = int((bounds.position.x + bounds.size.x + field_size.x / 2) / cell_size)
	var min_cell_y = int((bounds.position.y + field_size.y / 2) / cell_size)
	var max_cell_y = int((bounds.position.y + bounds.size.y + field_size.y / 2) / cell_size)
	
	# Clear visible stars
	visible_near_stars.clear()
	visible_far_stars.clear()
	
	# Calculate stars per cell (distribute total stars across visible cells)
	var cells_x = max_cell_x - min_cell_x + 1
	var cells_y = max_cell_y - min_cell_y + 1
	var total_cells = cells_x * cells_y
	var near_per_cell = max(1, int(near_star_count / max(total_cells, 1)))
	var far_per_cell = max(1, int(far_star_count / max(total_cells, 1)))
	
	# Generate and collect visible stars
	for cell_x in range(min_cell_x, max_cell_x + 1):
		for cell_y in range(min_cell_y, max_cell_y + 1):
			var near_stars = _generate_stars_for_cell(cell_x, cell_y, "near", near_per_cell)
			var far_stars = _generate_stars_for_cell(cell_x, cell_y, "far", far_per_cell)
			
			# Cull stars outside bounds
			for star in near_stars:
				var star_world_pos = star.position
				if bounds.has_point(star_world_pos):
					visible_near_stars.append(star)
			
			for star in far_stars:
				var star_world_pos = star.position
				if bounds.has_point(star_world_pos):
					visible_far_stars.append(star)

func _process(_delta: float) -> void:
	# Update camera reference if needed
	if not camera:
		_find_camera()
		return
	
	# Get viewport size and account for camera zoom
	var viewport = get_viewport()
	if not viewport:
		return
	
	var viewport_size = viewport.get_visible_rect().size
	var camera_zoom = camera.zoom
	# Account for zoom - when zoomed in, viewport covers less world space
	var world_viewport_size = viewport_size / camera_zoom
	var camera_pos = camera.global_position
	
	# Update visible stars based on camera position
	_update_visible_stars(camera_pos, world_viewport_size)
	
	# Queue redraw to update star positions and twinkling
	queue_redraw()

func _draw() -> void:
	if not camera:
		return
	
	var camera_pos = camera.global_position
	
	# Draw black background covering the entire viewport
	var viewport = get_viewport()
	if viewport:
		var viewport_size = viewport.get_visible_rect().size
		var camera_zoom = camera.zoom
		var world_viewport_size = viewport_size / camera_zoom
		
		# Draw a large black rectangle centered on camera
		var bg_rect = Rect2(
			camera_pos - world_viewport_size / 2.0 - Vector2(cull_margin, cull_margin),
			world_viewport_size + Vector2(cull_margin * 2.0, cull_margin * 2.0)
		)
		draw_rect(bg_rect, Color.BLACK)
	
	# Draw far stars (slow parallax)
	for star in visible_far_stars:
		_draw_star(star, camera_pos, far_parallax_speed)
	
	# Draw near stars (fast parallax)
	for star in visible_near_stars:
		_draw_star(star, camera_pos, near_parallax_speed)

func _draw_star(star: StarData, camera_pos: Vector2, parallax_speed: float) -> void:
	# Calculate draw position with parallax
	# Stars move at parallax_speed fraction of camera movement
	# For parallax_speed = 0.2, stars move at 20% of camera speed
	var draw_pos = star.position - camera_pos * parallax_speed
	
	# Calculate twinkling effect
	var time = Time.get_ticks_msec() / 1000.0
	var twinkle = sin(time * twinkle_speed + star.twinkle_offset)
	var brightness = 1.0 - (twinkle_amount * (1.0 - twinkle) / 2.0)
	
	# Apply twinkling to color
	var twinkled_color = Color(
		star.color.r * brightness,
		star.color.g * brightness,
		star.color.b * brightness,
		star.color.a
	)
	
	# Draw star as a circle
	draw_circle(draw_pos, star.size, twinkled_color)
