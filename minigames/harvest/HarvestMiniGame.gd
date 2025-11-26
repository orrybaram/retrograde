extends Node
class_name HarvestMiniGame

## Scanner-style harvest mini-game.
## Vertical bar moves left-right, player must press scan when bar is over resource square.

signal harvest_success(amount: int)
signal harvest_failed()
signal ui_opened()
signal ui_closed()

var resource_kind: String = "Scrap"
var resource_amount: int = 10
var is_open: bool = false
var input_action: String = "scan"

# Scanner mechanics
@export var scanner_speed: float = 0.5  # Speed of scanner movement (units per second)
@export var grid_cells: int = 10  # Number of grid cells (square grid)
var scanner_position: float = 0.0  # Position from 0.0 (left) to 1.0 (right)
var moving_right: bool = true  # Direction of movement
var resource_positions: Array[Vector2i] = []  # Grid cell positions (column, row) where resources are located

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	if not is_open:
		return
	
	# Move scanner bar continuously
	if moving_right:
		scanner_position += scanner_speed * delta
		if scanner_position >= 1.0:
			scanner_position = 1.0
			moving_right = false
	else:
		scanner_position -= scanner_speed * delta
		if scanner_position <= 0.0:
			scanner_position = 0.0
			moving_right = true
	
	# Check for scan input
	if Input.is_action_just_pressed(input_action):
		if is_bar_over_resource():
			# Success! Harvest all resources
			harvest_success.emit(resource_amount)
			await get_tree().create_timer(1.0).timeout
			close_ui()
		else:
			# Failure! Game ends, no resources
			harvest_failed.emit()
			await get_tree().create_timer(1.0).timeout
			close_ui()

func is_bar_over_resource() -> bool:
	if resource_positions.is_empty():
		return false
	
	# Calculate which grid column the scanner is currently over
	var current_column = int(scanner_position * grid_cells)
	current_column = clamp(current_column, 0, grid_cells - 1)
	
	# Check if any resource is at this column (any row in this column)
	for resource_pos in resource_positions:
		if resource_pos.x == current_column:
			return true
	
	return false

func get_scanner_position() -> float:
	return scanner_position

func open_ui(kind: String, amount: int) -> void:
	if is_open:
		return
	
	resource_kind = kind
	resource_amount = amount
	is_open = true
	scanner_position = 0.0
	moving_right = true
	
	# Initialize with 1 resource at a random grid cell position
	resource_positions.clear()
	var random_column = randi() % grid_cells
	var random_row = randi() % grid_cells
	resource_positions.append(Vector2i(random_column, random_row))
	
	set_process(true)
	ui_opened.emit()

func close_ui() -> void:
	if not is_open:
		return
	
	is_open = false
	set_process(false)
	ui_closed.emit()
