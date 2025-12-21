extends Control
class_name IndicatorManager

## Central manager that tracks all indicator targets and displays a single indicator at a time.

@export var indicator_color: Color = Colors.INDICATOR
@export var info_box_offset: Vector2 = Vector2(150, -80)  # Offset from bracket to info box

var targets: Array[IndicatorTarget] = []
var current_target: IndicatorTarget = null
var info_box: Control = null
var ship: Ship = null
var camera: Camera2D = null

func _ready() -> void:
	add_to_group("indicator_manager")
	process_mode = Node.PROCESS_MODE_ALWAYS  # Always process so indicators work when paused
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse input

func _process(_delta: float) -> void:
	# Find ship and camera if not set
	if not ship:
		ship = get_tree().get_first_node_in_group("ship") as Ship
	if not camera and ship:
		camera = ship.get_node_or_null("Camera2D") as Camera2D
	
	# Filter targets to only visible ones
	var visible_targets: Array[IndicatorTarget] = []
	for target in targets:
		if target and target.is_indicator_visible():
			visible_targets.append(target)
	
	# Select target with highest priority, or closest if priorities equal
	var selected_target: IndicatorTarget = null
	if not visible_targets.is_empty():
		# Sort by priority (descending), then by distance
		visible_targets.sort_custom(_compare_targets)
		selected_target = visible_targets[0]
	
	# Update current target
	if current_target != selected_target:
		current_target = selected_target
		_update_info_box()
	
	# Update indicator display
	queue_redraw()

func _compare_targets(a: IndicatorTarget, b: IndicatorTarget) -> bool:
	var priority_a = a.get_indicator_priority()
	var priority_b = b.get_indicator_priority()
	
	# Higher priority first
	if priority_a != priority_b:
		return priority_a > priority_b
	
	# If priorities equal, closer to ship first
	if ship:
		var dist_a = ship.global_position.distance_to(a.get_indicator_position())
		var dist_b = ship.global_position.distance_to(b.get_indicator_position())
		return dist_a < dist_b
	
	return false

func _draw() -> void:
	if not current_target or not camera:
		return
	
	var target_node = current_target.get_indicator_node()
	if not target_node or not is_instance_valid(target_node):
		return
	
	# Convert world position to screen position
	var world_pos = current_target.get_indicator_position()
	var camera_pos = camera.global_position
	var viewport_size = get_viewport_rect().size
	var screen_center = viewport_size / 2.0
	
	# Convert world to screen: (world - camera) * zoom + screen_center
	var screen_pos = (world_pos - camera_pos) * camera.zoom + screen_center
	
	# Get bounds in screen space
	var bounds = current_target.get_indicator_bounds()
	var bounds_world_pos = target_node.global_position
	var bounds_screen_pos = (bounds_world_pos - camera_pos) * camera.zoom + screen_center
	
	# Adjust bounds to screen coordinates
	var bounds_offset_world = bounds.position
	var bounds_offset_screen = bounds_offset_world * camera.zoom
	var screen_bounds = Rect2(
		bounds_screen_pos + bounds_offset_screen,
		bounds.size * camera.zoom
	)
	
	# Draw bracket around bounds
	IndicatorRenderer.draw_bracket(self, screen_bounds, indicator_color)
	
	# Calculate info box position (end of dotted line)
	var info_box_pos = screen_pos + info_box_offset
	
	# Draw dotted line from bracket edge to info box
	var bracket_edge = screen_bounds.position + Vector2(screen_bounds.size.x / 2, screen_bounds.size.y)
	IndicatorRenderer.draw_dotted_line(self, bracket_edge, info_box_pos, indicator_color)
	
	# Position info box
	if info_box:
		info_box.position = info_box_pos
		info_box.visible = true

func _update_info_box() -> void:
	# Remove old info box
	if info_box:
		info_box.queue_free()
		info_box = null
	
	# Create new info box if we have a target
	if current_target:
		var info_data = current_target.get_indicator_info()
		info_box = IndicatorRenderer.create_info_box(info_data)
		add_child(info_box)
		info_box.visible = false  # Will be shown in _draw

## Register a target to be considered for indicator display
func register_target(target: IndicatorTarget) -> void:
	if target and not targets.has(target):
		targets.append(target)

## Unregister a target
func unregister_target(target: IndicatorTarget) -> void:
	targets.erase(target)
	if current_target == target:
		current_target = null
		_update_info_box()
