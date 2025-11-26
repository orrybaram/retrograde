extends Control
class_name ProgressBarWidget

## Reusable progress bar widget component.
## Can be used for any stat display (fuel, hull, health, etc.)

@onready var background_rect: ColorRect = $"BackgroundRect"
@onready var fill_rect: ColorRect = $"FillRect"
@onready var label: Label = $"Label"

@export var bar_color: Color = Color(1.0, 0.75, 0.0) :
	set(value):
		bar_color = value
		_update_colors()

@export var background_color: Color = Color(0, 0, 0, 1) :
	set(value):
		background_color = value
		_update_colors()

@export var show_label: bool = true :
	set(value):
		show_label = value
		

var current_value: float = 0.0
var max_value: float = 100.0

func _ready() -> void:
	_update_colors()
	_update_display()
	
	if label:
		label.visible = show_label

func set_value(current: float, max_val: float) -> void:
	current_value = current
	max_value = max_val
	_update_display()

func set_color(color: Color) -> void:
	bar_color = color

func set_label_text(text: String) -> void:
	if label:
		label.text = text

func _update_colors() -> void:
	if background_rect:
		background_rect.color = background_color
	if fill_rect:
		fill_rect.color = bar_color

func _update_display() -> void:
	if not fill_rect or max_value <= 0:
		return
	
	var fill_ratio = clamp(current_value / max_value, 0.0, 1.0)
	var bar_size = size.x * fill_ratio
	
	# Update fill bar width and height using set_deferred to avoid anchor warnings
	fill_rect.set_deferred("size", Vector2(bar_size, size.y))
	
	# Update label if shown
	if label and show_label:
		label.text = "%.0f / %.0f" % [current_value, max_value]

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_display()
