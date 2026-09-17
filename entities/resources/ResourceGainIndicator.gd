extends Control
class_name ResourceGainIndicator

## Reusable UI node that displays an animated "+<AMOUNT>" indicator.
## Appears in world space and scales based on harvest amount.

@onready var amount_label: Label = $AmountLabel

@export var animation_duration: float = 1.5
@export var scale_multiplier: float = 0.1  # Scale factor based on amount
@export var base_scale: float = 1.0
@export var upward_movement: float = 20.0  # Pixels to move upward during animation
var stack_offset: float = 0.0  # Screen px to start above the anchor, so live indicators don't overlap
var x_offset: float = 0.0  # Screen px sideways from the anchor, so repeated popups don't sit on one column

var _tween: Tween = null
var _world_position: Vector2 = Vector2.ZERO  # Store world position for tracking
var follow: Node2D = null  # When set, the text tracks this node instead of a fixed world point
var _rise := 0.0  # Animated upward drift in screen px

func _ready() -> void:
	visible = false
	modulate.a = 0.0

func _process(_delta: float) -> void:
	# Re-project every frame: the camera (and a followed node) keep moving.
	if visible:
		_place()

func _place() -> void:
	var anchor := follow.global_position if follow and is_instance_valid(follow) else _world_position
	position = _world_to_screen(anchor) + Vector2(x_offset, -(stack_offset + _rise))

## Convert world position to screen position (includes camera offset, smoothing and zoom)
func _world_to_screen(world_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_pos

## `tier_name` is the unit after the number ("" shows just "+N"). `style` picks the
## pop: "crystal" / "artifact" gem ids or "CR" for a cash-in.
func show_gain(amount: int, _resource_kind: String, world_position: Vector2, tier_name: String = "", tier_color: Color = Colors.PRIMARY, style: String = "") -> void:
	# Ensure nodes are ready (in case called before _ready)
	if not amount_label:
		amount_label = get_node_or_null("AmountLabel") as Label
	
	if not amount_label:
		push_error("ResourceGainIndicator: AmountLabel not found")
		return
	
	# Store world position for tracking
	_world_position = world_position
	
	# Set text
	if tier_name != "":
		amount_label.text = "+%d %s" % [amount, tier_name]
	else:
		amount_label.text = "+%d" % amount

	# Set the font color itself: modulate would multiply with the scene's mustard font color.
	amount_label.add_theme_color_override("font_color", tier_color)

	# Tier-based scale bonus
	var tier_scale_bonus := 0.0
	match style:
		"crystal": tier_scale_bonus = 0.2
		"artifact": tier_scale_bonus = 0.5
		"CR": tier_scale_bonus = 0.3

	# Calculate scale based on amount
	var target_scale = base_scale + (amount * scale_multiplier) + tier_scale_bonus
	target_scale = clamp(target_scale, base_scale, base_scale * 1.8)  # Cap at 1.8x base scale
	
	# Set initial state — start smaller for bigger pop
	scale = Vector2(0.3, 0.3)
	modulate.a = 0.0
	_rise = 0.0
	_place()
	visible = true
	set_process(true)  # Enable processing to track camera movement

	# Start animation
	_animate_text(target_scale, style)

func _animate_text(target_scale: float, style: String = "") -> void:
	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)

	var end_scale = target_scale
	var is_artifact = style == "artifact"

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
	_tween.tween_property(self, "_rise", upward_movement, animation_duration)
	
	# Fade out (starts after peak)
	_tween.tween_property(self, "modulate:a", 0.0, animation_duration * 0.7).set_delay(animation_duration * 0.3)
	
	# Cleanup after animation
	_tween.tween_callback(_on_animation_complete).set_delay(animation_duration)

func _on_animation_complete() -> void:
	visible = false
	queue_free()
