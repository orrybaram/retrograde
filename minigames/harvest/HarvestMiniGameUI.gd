extends Control
class_name HarvestMiniGameUI

## Scanner-style terminal UI for resource harvesting.
## Shows scanner bar and resource squares, player must press scan when bar is over resource.

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var resource_label: Label = $MarginContainer/VBoxContainer/ResourceLabel
@onready var scanner_container: Control = $MarginContainer/VBoxContainer/ScannerContainer
@onready var vertical_scanner_bar: ColorRect = $MarginContainer/VBoxContainer/ScannerContainer/VerticalScannerBar
@onready var horizontal_scanner_bar: ColorRect = $MarginContainer/VBoxContainer/ScannerContainer/HorizontalScannerBar
@onready var resource_squares_container: Control = $MarginContainer/VBoxContainer/ScannerContainer/ResourceSquaresContainer

var mini_game: HarvestMiniGame = null
var terminal_color: Color = Color(1.0, 0.75, 0.0)  # Amber/orange terminal color
var resource_squares: Array[ColorRect] = []  # Dynamic resource square nodes

func _ready() -> void:
	visible = false

func _process(_delta: float) -> void:
	if not mini_game or mini_game.is_idle():
		return
	
	_update_scanner()
	_update_resource_squares()

func setup(mini_game_instance: HarvestMiniGame) -> void:
	mini_game = mini_game_instance
	
	if mini_game:
		mini_game.harvest_success.connect(_on_harvest_success)
		mini_game.harvest_failed.connect(_on_harvest_failed)
		mini_game.ui_opened.connect(_on_ui_opened)
		mini_game.ui_closed.connect(_on_ui_closed)
		
		_update_display()

func cleanup() -> void:
	if mini_game:
		if mini_game.harvest_success.is_connected(_on_harvest_success):
			mini_game.harvest_success.disconnect(_on_harvest_success)
		if mini_game.harvest_failed.is_connected(_on_harvest_failed):
			mini_game.harvest_failed.disconnect(_on_harvest_failed)
		if mini_game.ui_opened.is_connected(_on_ui_opened):
			mini_game.ui_opened.disconnect(_on_ui_opened)
		if mini_game.ui_closed.is_connected(_on_ui_closed):
			mini_game.ui_closed.disconnect(_on_ui_closed)
	
	_clear_resource_squares()
	mini_game = null
	visible = false

func _update_display() -> void:
	if not mini_game:
		return
	
	if title_label:
		title_label.text = "SCANNER"
	
	if resource_label:
		resource_label.text = "Resource: %s" % [mini_game.resource_kind]
	
func _update_scanner() -> void:
	if not mini_game:
		return
	
	var current_state = mini_game.get_current_state()
	if current_state:
		current_state.update_visuals(self)

func _update_resource_squares() -> void:
	if not mini_game or not resource_squares_container:
		return
	
	var container_width = resource_squares_container.size.x
	var container_height = resource_squares_container.size.y
	var grid_cells = mini_game.grid_cells
	
	# Calculate cell size for each dimension to match GridBackground (fills entire container)
	var cell_width = container_width / grid_cells
	var cell_height = container_height / grid_cells
	
	# Create/update resource squares
	if resource_squares.size() != mini_game.resource_positions.size():
		_clear_resource_squares()
		_create_resource_squares()
	
	# Position resource squares at their grid cell positions
	for i in range(mini_game.resource_positions.size()):
		if i >= resource_squares.size():
			continue
		
		var cell_pos = mini_game.resource_positions[i]
		var square = resource_squares[i]
		
		# Calculate position: center of the grid cell
		var square_x = cell_pos.x * cell_width + (cell_width / 2.0) - (square.size.x / 2.0)
		var square_y = cell_pos.y * cell_height + (cell_height / 2.0) - (square.size.y / 2.0)
		
		square.position.x = square_x
		square.position.y = square_y

func _create_resource_squares() -> void:
	if not mini_game or not resource_squares_container:
		return
	
	for _i in range(mini_game.resource_positions.size()):
		var square = ColorRect.new()
		square.size = Vector2(20, 20)
		square.color = terminal_color
		resource_squares_container.add_child(square)
		resource_squares.append(square)

func _clear_resource_squares() -> void:
	for square in resource_squares:
		if is_instance_valid(square):
			square.queue_free()
	resource_squares.clear()

func _on_harvest_success(_tier_item_id: String, _tier_name: String) -> void:
	# Harvest successful - UI will close automatically
	pass

func _on_harvest_failed() -> void:
	# Harvest failed - UI will close automatically
	pass

func _on_ui_opened() -> void:
	visible = true
	_update_display()
	_create_resource_squares()

func _on_ui_closed() -> void:
	visible = false
	_clear_resource_squares()
