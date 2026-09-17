extends Control
class_name IndicatorManager

## Central manager that tracks all indicator targets and displays a single indicator at a time.
## Also shows the current action prompt (EventBus.action_message_changed) in context:
## tucked under the scrap callout while harvesting is possible, otherwise just below the ship.

@export var indicator_color: Color = Colors.INDICATOR
@export var info_box_offset: Vector2 = Vector2(150, -80)  # Offset from bracket to info box

var targets: Array[IndicatorTarget] = []
var current_target: IndicatorTarget = null
var info_box: Control = null
var ship: Ship = null
var camera: Camera2D = null

const PROMPT_FONT_SIZE := 8
const PROMPT_GAP := 6.0
const PROMPT_SHIP_OFFSET := 26.0  # below the ship's center, in screen px
const PROMPT_ALPHA := 0.7
const PROMPT_OUTLINE := 4  # dark halo so the hint reads over the landing bay stripes

var _prompt: Label
var _prompt_text := ""

func _ready() -> void:
	add_to_group("indicator_manager")
	process_mode = Node.PROCESS_MODE_ALWAYS  # Always process so indicators work when paused
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse input

	_prompt = Label.new()
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_theme_font_size_override("font_size", PROMPT_FONT_SIZE)
	_prompt.add_theme_color_override("font_color", Colors.PRIMARY)
	_prompt.add_theme_color_override("font_outline_color", Colors.SPACE_BG)
	_prompt.add_theme_constant_override("outline_size", PROMPT_OUTLINE)
	_prompt.visible = false
	add_child(_prompt)
	EventBus.action_message_changed.connect(_on_action_message_changed)
	if EventBus.is_harvest_available():
		_on_action_message_changed(EventBus.harvest_prompt())

func _on_action_message_changed(message: String) -> void:
	_prompt_text = message
	if _prompt.text != message:
		_prompt.text = message
		_prompt.reset_size()

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
	elif current_target and info_box:
		IndicatorRenderer.update_info_box(info_box, current_target.get_indicator_info())
	
	_place_prompt()

	# Update indicator display
	queue_redraw()

## Harvest prompt hangs under the scrap callout; anything else sits under the ship.
func _place_prompt() -> void:
	var shown := _prompt_text != "" and camera != null and is_instance_valid(ship) and not get_tree().paused
	# Full hold: the scrap callout already says so, don't nag to harvest
	if shown and ship.is_cargo_full() and _prompt_text == EventBus.harvest_prompt():
		shown = false
	_prompt.visible = shown
	if not shown:
		return
	# Soft breathing so it reads as a hint, not a banner
	_prompt.modulate.a = PROMPT_ALPHA * (0.75 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 0.6))
	var viewport_size := get_viewport_rect().size
	var pos: Vector2
	if info_box and current_target and EventBus.is_harvest_available():
		pos = _info_box_screen_pos() + Vector2(IndicatorRenderer.INFO_BOX_PADDING, info_box.size.y + PROMPT_GAP)
	else:
		var ship_screen := (ship.global_position - camera.global_position) * camera.zoom + viewport_size / 2.0
		pos = ship_screen + Vector2(-_prompt.size.x / 2.0, PROMPT_SHIP_OFFSET)
	_prompt.position = pos.clamp(Vector2.ZERO, (viewport_size - _prompt.size).max(Vector2.ZERO)).round()

func _info_box_screen_pos() -> Vector2:
	var viewport_size := get_viewport_rect().size
	var screen_pos := (current_target.get_indicator_position() - camera.global_position) * camera.zoom + viewport_size / 2.0
	return (screen_pos + info_box_offset).clamp(Vector2.ZERO, (viewport_size - info_box.size).max(Vector2.ZERO))

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
	if info_box:
		info_box_pos = info_box_pos.clamp(Vector2.ZERO, (viewport_size - info_box.size).max(Vector2.ZERO))
	
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
