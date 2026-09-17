extends Control
class_name ResourceGainIndicator

## Reusable UI node that displays an animated "+<AMOUNT>" indicator.
## Appears in world space and scales based on harvest amount.

@onready var amount_label: Label = $AmountLabel

@export var animation_duration: float = 1.5
@export var scale_multiplier: float = 0.1  # Scale factor based on amount
@export var base_scale: float = 1.0
@export var upward_movement: float = 20.0  # Pixels to move upward during animation

var _tween: Tween = null
var _camera: Camera2D = null
var _world_position: Vector2 = Vector2.ZERO  # Store world position for tracking

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	
	# Find camera for world-to-screen conversion
	_find_camera()

func _process(_delta: float) -> void:
	# Update screen position based on camera movement
	if visible and _world_position != Vector2.ZERO:
		var screen_pos = _world_to_screen(_world_position)
		# Only update x position (y is animated upward)
		position.x = screen_pos.x

func _find_camera() -> void:
	var ship = get_tree().get_first_node_in_group("ship")
	if ship:
		_camera = ship.get_node_or_null("Camera2D") as Camera2D
	
	if not _camera:
		# Fallback: find any Camera2D in scene
		_camera = get_tree().get_first_node_in_group("camera") as Camera2D

## Convert world position to screen position
func _world_to_screen(world_pos: Vector2) -> Vector2:
	if not _camera:
		_find_camera()
	
	if not _camera:
		# Fallback: return world position if no camera found
		return world_pos
	
	var viewport_size = get_viewport_rect().size
	var screen_center = viewport_size / 2.0
	var camera_pos = _camera.global_position
	var camera_zoom = _camera.zoom
	
	# Convert world to screen: (world - camera) * zoom + screen_center
	var screen_pos = (world_pos - camera_pos) * camera_zoom + screen_center
	return screen_pos

## Show the gain indicator animation
func show_gain(amount: int, _resource_kind: String, world_position: Vector2, tier_name: String = "", tier_color: Color = Colors.PRIMARY) -> void:
	# Ensure nodes are ready (in case called before _ready)
	if not amount_label:
		amount_label = get_node_or_null("AmountLabel") as Label
	
	if not amount_label:
		push_error("ResourceGainIndicator: AmountLabel not found")
		return
	
	# Store world position for tracking
	_world_position = world_position
	
	# Ensure camera is found
	if not _camera:
		_find_camera()
	
	# Set text
	if tier_name != "":
		amount_label.text = "+%d %s" % [amount, tier_name]
	else:
		amount_label.text = "+%d" % amount

	# Apply tier color to label (keeps fade animation on self.modulate)
	amount_label.modulate = tier_color

	# Tier-based scale bonus
	var tier_scale_bonus := 0.0
	match tier_name:
		"Salvage": tier_scale_bonus = 0.1
		"Component": tier_scale_bonus = 0.2
		"Mil-Spec": tier_scale_bonus = 0.3
		"Artifact": tier_scale_bonus = 0.5

	# Calculate scale based on amount
	var target_scale = base_scale + (amount * scale_multiplier) + tier_scale_bonus
	target_scale = clamp(target_scale, base_scale, base_scale * 1.8)  # Cap at 1.8x base scale
	
	# Convert world position to screen position
	var screen_pos = _world_to_screen(world_position)
	
	if not _camera:
		push_warning("ResourceGainIndicator: Camera not found, using world position")
	
	# Set initial state — start smaller for bigger pop
	scale = Vector2(0.3, 0.3)
	modulate.a = 0.0
	position = screen_pos
	visible = true
	set_process(true)  # Enable processing to track camera movement

	# Start animation
	_animate_text(target_scale, tier_name)

func _animate_text(target_scale: float, tier_name: String = "") -> void:
	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)

	var end_scale = target_scale
	var is_artifact = tier_name == "Artifact"

	# Artifact: extra overshoot to 1.5x before settling
	var peak_scale = target_scale * (1.5 if is_artifact else 1.2)

	# Scale up to peak (with ease out)
	_tween.tween_property(self, "scale", Vector2(peak_scale, peak_scale), animation_duration * 0.3).set_ease(Tween.EASE_OUT)

	# Artifact: second bounce — dip below then settle
	if is_artifact:
		var dip_scale = end_scale * 0.85
		_tween.tween_property(self, "scale", Vector2(dip_scale, dip_scale), animation_duration * 0.15).set_delay(animation_duration * 0.3).set_ease(Tween.EASE_IN)
		_tween.tween_property(self, "scale", Vector2(end_scale, end_scale), animation_duration * 0.1).set_delay(animation_duration * 0.45).set_ease(Tween.EASE_OUT)
	else:
		# Scale back slightly (with ease in)
		_tween.tween_property(self, "scale", Vector2(end_scale, end_scale), animation_duration * 0.2).set_delay(animation_duration * 0.3).set_ease(Tween.EASE_IN)
	
	# Fade in
	_tween.tween_property(self, "modulate:a", 1.0, animation_duration * 0.2)
	
	# Move upward
	var start_y = position.y
	var end_y = start_y - upward_movement
	_tween.tween_property(self, "position:y", end_y, animation_duration)
	
	# Fade out (starts after peak)
	_tween.tween_property(self, "modulate:a", 0.0, animation_duration * 0.7).set_delay(animation_duration * 0.3)
	
	# Cleanup after animation
	_tween.tween_callback(_on_animation_complete).set_delay(animation_duration)

func _on_animation_complete() -> void:
	visible = false
	queue_free()
