extends Node
class_name HarvestMiniGame

## Two-phase scanner-style harvest mini-game with class-based state machine.
## Phase 1: Player sets vertical scan line position
## Phase 2: Player sets horizontal scan line position
## Harvest amount based on distance from intersection point.

signal harvest_success(tier_item_id: String, tier_name: String)  # Emitted by CompleteState when harvest succeeds
signal harvest_failed()  # Emitted by CompleteState when harvest fails
signal ui_opened()
signal ui_closed()

# Note: harvest_success and harvest_failed signals are emitted by CompleteState,
# not directly in this class, which is why the linter shows them as unused.

var resource_kind: String = "Scrap"
var resource_amount: int = 10
var input_action: String = "action"

# Scanner mechanics
@export var scanner_speed: float = 1  # Speed of scanner movement (units per second)
@export var grid_cells: int = 10  # Number of grid cells (square grid)
@export var max_harvest_distance: float = 3.0  # Maximum distance for harvesting (in grid cells)

# State machine
var current_state: HarvestMiniGameState

# Two-phase scanning variables
var vertical_line_position: float = 0.0  # Position from 0.0 (left) to 1.0 (right)
var horizontal_line_position: float = 0.0  # Position from 0.0 (top) to 1.0 (bottom)
var vertical_locked: bool = false
var horizontal_locked: bool = false
var vertical_moving_right: bool = true
var horizontal_moving_down: bool = true

var resource_positions: Array[Vector2i] = []  # Grid cell positions (column, row) where resources are located

func _ready() -> void:
	# Initialize with idle state
	current_state = IdleState.new(self)
	current_state.enter()
	set_process(false)

func _process(delta: float) -> void:
	if current_state:
		current_state.process(delta)
	
	# Check for input
	if Input.is_action_just_pressed(input_action):
		if current_state:
			current_state.handle_input(input_action)

func change_state(new_state: HarvestMiniGameState) -> void:
	if current_state:
		current_state.exit()
	
	current_state = new_state
	
	if current_state:
		current_state.enter()

func calculate_harvest_amount() -> int:
	if resource_positions.is_empty():
		return 0

	# Calculate intersection point in grid coordinates
	var intersection_x = vertical_line_position * grid_cells
	var intersection_y = horizontal_line_position * grid_cells

	# Check if intersection is close enough to any resource position
	for resource_pos in resource_positions:
		var resource_x = float(resource_pos.x) + 0.5  # Center of cell
		var resource_y = float(resource_pos.y) + 0.5  # Center of cell

		var dx = resource_x - intersection_x
		var dy = resource_y - intersection_y
		var distance = sqrt(dx * dx + dy * dy)

		if distance <= max_harvest_distance:
			return 1

	return 0

func get_vertical_line_position() -> float:
	return vertical_line_position

func get_horizontal_line_position() -> float:
	return horizontal_line_position

func get_current_state() -> HarvestMiniGameState:
	return current_state

func is_idle() -> bool:
	return current_state is IdleState

func open_ui(kind: String, amount: int) -> void:
	if not is_idle():
		return
	
	resource_kind = kind
	resource_amount = amount
	
	# Reset two-phase scanning variables
	vertical_line_position = 0.0
	horizontal_line_position = 0.0
	vertical_locked = false
	horizontal_locked = false
	vertical_moving_right = true
	horizontal_moving_down = true
	
	# Initialize with 1 resource at a random grid cell position
	resource_positions.clear()
	var random_column = randi() % grid_cells
	var random_row = randi() % grid_cells
	resource_positions.append(Vector2i(random_column, random_row))
	
	# Transition to vertical phase state
	change_state(VerticalPhaseState.new(self))
	ui_opened.emit()

func close_ui() -> void:
	if is_idle():
		return
	
	# Transition to idle state
	change_state(IdleState.new(self))
	set_process(false)
	ui_closed.emit()
