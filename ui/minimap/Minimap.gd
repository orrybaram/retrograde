extends Control
class_name Minimap

## Radar-style minimap that displays the ship and nearby tracked entities.

## The display radius of the minimap in pixels
@export var display_radius: float = 70.0

## The world range that the minimap covers (in world units)
@export var world_range: float = 5000.0

## Colors
@export var background_color: Color = Color(0.0, 0.0, 0.0, 0.8)
@export var border_color: Color = Color(1.0, 0.75, 0.0, 1.0)  # Amber
@export var ring_color: Color = Color(1.0, 0.75, 0.0, 0.3)  # Faded amber
@export var ship_color: Color = Color(1.0, 0.75, 0.0, 1.0)  # Amber

## Whether to rotate the minimap with the ship's heading
@export var rotate_with_ship: bool = false

## Number of radar rings to display
@export var ring_count: int = 3

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
	_draw_ship_indicator(center, ship_rotation)

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
		_:
			draw_circle(screen_pos, target_size, target_color)

func _draw_ship_indicator(center: Vector2, ship_rotation: float) -> void:
	# Draw a small triangle pointing in the ship's direction
	var ship_size = 6.0
	var angle = 0.0 if rotate_with_ship else ship_rotation - PI/2
	
	_draw_triangle(center, ship_size, ship_color, angle)

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

