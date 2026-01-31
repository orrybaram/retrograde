extends Control
class_name Minimap

## Radar-style minimap that displays the ship and nearby tracked entities.

## The display radius of the minimap in pixels
@export var display_radius: float = 70.0

## The world range that the minimap covers (in world units)
@export var world_range: float = 10000.0

## Planet size scaling
@export var planet_size_multiplier: float = 1.0  ## Multiplier to make planets visible on minimap

## Colors
@export var background_color: Color = Colors.UI_BACKGROUND_LIGHT
@export var border_color: Color = Colors.UI_BORDER
@export var ring_color: Color = Colors.PRIMARY_MEDIUM
@export var ship_color: Color = Colors.PRIMARY

## Whether to rotate the minimap with the ship's heading
@export var rotate_with_ship: bool = false

## Number of radar rings to display
@export var ring_count: int = 4

var targets: Array[MinimapTarget] = []
var ship: Ship = null

func _ready() -> void:
	add_to_group("minimap")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Set minimum size based on display radius
	custom_minimum_size = Vector2(display_radius * 2 + 20, display_radius * 2 + 20)

func _process(_delta: float) -> void:
	# Find ship if not set
	if not ship or not is_instance_valid(ship):
		ship = get_tree().get_first_node_in_group("ship") as Ship
	
	# Redraw every frame
	queue_redraw()

func _draw() -> void:
	var center = size / 2.0
	
	# Draw background circle
	draw_circle(center, display_radius + 2, background_color)
	
	# Draw radar rings
	for i in range(1, ring_count + 1):
		var ring_radius = display_radius * (float(i) / float(ring_count))
		draw_arc(center, ring_radius, 0, TAU, 64, ring_color, 1.0)
	
	# Draw border
	draw_arc(center, display_radius, 0, TAU, 64, border_color, 2.0)
	
	# Draw cardinal direction indicators
	_draw_cardinal_indicators(center)
	
	if not ship or not is_instance_valid(ship):
		return
	
	var ship_rotation = ship.rotation if rotate_with_ship else 0.0
	
	# Draw all visible targets
	var visible_targets: Array[MinimapTarget] = []
	for target in targets:
		if target and target.is_minimap_visible():
			visible_targets.append(target)
	
	# Sort by priority (lower priority drawn first, so higher priority is on top)
	visible_targets.sort_custom(func(a, b): return a.get_minimap_priority() < b.get_minimap_priority())
	
	for target in visible_targets:
		_draw_target(center, target, ship_rotation)
	
	# Draw ship indicator at center (always on top)
	_draw_ship_indicator(center)

func _draw_cardinal_indicators(center: Vector2) -> void:
	var indicator_distance = display_radius + 8
	var font = ThemeDB.fallback_font
	var font_size = 8
	
	# Only draw if not rotating (otherwise directions don't make sense)
	if not rotate_with_ship:
		# N, E, S, W
		var directions = ["N", "E", "S", "W"]
		var angles = [-PI/2, 0, PI/2, PI]
		
		for i in range(4):
			var pos = center + Vector2(cos(angles[i]), sin(angles[i])) * indicator_distance
			var text_size = font.get_string_size(directions[i], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			draw_string(font, pos - text_size / 2, directions[i], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, border_color)

func _draw_target(center: Vector2, target: MinimapTarget, ship_rotation: float) -> void:
	var target_pos = target.get_minimap_position()
	var ship_pos = ship.global_position
	
	# Calculate relative position
	var relative_pos = target_pos - ship_pos
	
	# Rotate if needed (negative rotation + offset to align "up" with ship forward)
	if rotate_with_ship:
		relative_pos = relative_pos.rotated(-ship_rotation - PI/2)
	
	# Scale to minimap coordinates
	var minimap_pos = relative_pos / world_range * display_radius
	
	var target_size = target.get_minimap_size()
	
	# Skip targets only when they've fully exited the bounds (center + size is outside)
	if minimap_pos.length() > display_radius + target_size:
		return
	
	var screen_pos = center + minimap_pos
	var target_color = target.get_minimap_color()
	var icon = target.get_minimap_icon()
	
	match icon:
		"dot":
			draw_circle(screen_pos, target_size, target_color)
		"diamond":
			_draw_diamond(screen_pos, target_size, target_color)
		"triangle":
			_draw_triangle(screen_pos, target_size, target_color, 0)
		"square":
			var rect = Rect2(screen_pos - Vector2(target_size, target_size), Vector2(target_size * 2, target_size * 2))
			draw_rect(rect, target_color)
		"ring":
			_draw_resource_ring(center, target, ship_rotation)
		_:
			draw_circle(screen_pos, target_size, target_color)

func _draw_ship_indicator(center: Vector2) -> void:
	# Draw a crosshair at the center
	_draw_crosshair(center, 6.0, ship_color)

func _draw_crosshair(pos: Vector2, marker_size: float, color: Color) -> void:
	var line_width = 1.5
	# Horizontal line
	draw_line(pos + Vector2(-marker_size, 0), pos + Vector2(marker_size, 0), color, line_width)
	# Vertical line
	draw_line(pos + Vector2(0, -marker_size), pos + Vector2(0, marker_size), color, line_width)

func _draw_triangle(pos: Vector2, marker_size: float, color: Color, angle: float) -> void:
	var points = PackedVector2Array()
	# Triangle pointing up by default
	var base_points = [
		Vector2(0, -marker_size),      # Top
		Vector2(-marker_size * 0.7, marker_size * 0.5),  # Bottom left
		Vector2(marker_size * 0.7, marker_size * 0.5)    # Bottom right
	]
	
	for point in base_points:
		points.append(pos + point.rotated(angle))
	
	draw_polygon(points, PackedColorArray([color, color, color]))

func _draw_diamond(pos: Vector2, marker_size: float, color: Color) -> void:
	var points = PackedVector2Array([
		pos + Vector2(0, -marker_size),     # Top
		pos + Vector2(marker_size, 0),      # Right
		pos + Vector2(0, marker_size),      # Bottom
		pos + Vector2(-marker_size, 0)      # Left
	])
	draw_polygon(points, PackedColorArray([color, color, color, color]))

func _draw_resource_ring(center: Vector2, target: MinimapTarget, ship_rotation: float) -> void:
	# Draw resource ring as clustered blobs based on actual resource positions
	if not target is ResourceRingMinimapTarget:
		return

	var ring_target = target as ResourceRingMinimapTarget
	var clusters = ring_target.get_clusters()
	var ring_color = ring_target.get_minimap_color()
	var max_count = ring_target.get_max_cluster_count()

	# Get the orbital body's current position (recalculated each frame)
	var orbital_center = ring_target.get_minimap_position()
	var ship_pos = ship.global_position

	# Draw each cluster as a blob sized by resource count
	for cluster in clusters:
		# Calculate world position from angle and radius relative to orbital body
		var angle = cluster["angle"]
		var radius = cluster["radius"]
		var count = cluster["count"]

		var cluster_pos = orbital_center + Vector2(cos(angle), sin(angle)) * radius
		var relative_pos = cluster_pos - ship_pos

		if rotate_with_ship:
			relative_pos = relative_pos.rotated(-ship_rotation - PI/2)

		var minimap_pos = center + relative_pos / world_range * display_radius

		# Skip if outside minimap bounds
		if minimap_pos.distance_to(center) > display_radius + 5:
			continue

		# Scale blob size by resource count (1.5 to 4.0)
		var size_ratio = float(count) / float(max_count)
		var blob_size = lerp(1.5, 4.0, size_ratio)

		# Vary alpha slightly by density
		var alpha = lerp(0.5, 0.9, size_ratio)
		var blob_color = Color(ring_color.r, ring_color.g, ring_color.b, alpha)

		draw_circle(minimap_pos, blob_size, blob_color)

## Register a target to be displayed on the minimap
func register_target(target: MinimapTarget) -> void:
	if target and not targets.has(target):
		targets.append(target)

## Unregister a target from the minimap
func unregister_target(target: MinimapTarget) -> void:
	targets.erase(target)

## Get the minimap singleton (convenience method)
static func get_instance(tree: SceneTree) -> Minimap:
	var minimap = tree.get_first_node_in_group("minimap")
	return minimap as Minimap
