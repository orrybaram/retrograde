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
var _line_flash_tween: Tween = null
var _intersection_tween: Tween = null
var _fail_flash_tween: Tween = null

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
		mini_game.ui = self
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

## Flash a scanner bar white→green with a width punch on line lock
func flash_line_lock(bar: ColorRect, is_vertical: bool) -> void:
	if _line_flash_tween and _line_flash_tween.is_valid():
		_line_flash_tween.kill()

	_line_flash_tween = create_tween()
	_line_flash_tween.set_parallel(true)

	# Color flash: white → green
	bar.color = Color(1.0, 1.0, 1.0, 1.0)
	_line_flash_tween.tween_property(bar, "color", Color(0.0, 1.0, 0.0, 0.9), 0.15)

	# Width/height punch
	var original_size: float
	var property: String
	if is_vertical:
		original_size = 2.0
		property = "size:x"
		bar.size.x = 2.0 * 1.5
	else:
		original_size = 2.0
		property = "size:y"
		bar.size.y = 2.0 * 1.5
	_line_flash_tween.tween_property(bar, property, original_size, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

## Pulse a glow ring at the intersection of both locked lines
func flash_intersection(v_pos: float, h_pos: float) -> void:
	if not scanner_container:
		return

	var container_width = scanner_container.size.x
	var container_height = scanner_container.size.y
	var x = v_pos * container_width
	var y = h_pos * container_height

	var ring = ColorRect.new()
	ring.size = Vector2(6, 6)
	ring.position = Vector2(x - 3, y - 3)
	ring.color = Color(0.0, 1.0, 0.0, 1.0)
	scanner_container.add_child(ring)

	if _intersection_tween and _intersection_tween.is_valid():
		_intersection_tween.kill()

	_intersection_tween = create_tween()
	_intersection_tween.set_parallel(true)
	# Scale up the ring
	ring.pivot_offset = ring.size / 2.0
	ring.scale = Vector2(1.0, 1.0)
	_intersection_tween.tween_property(ring, "scale", Vector2(4.0, 4.0), 0.4).set_ease(Tween.EASE_OUT)
	_intersection_tween.tween_property(ring, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	_intersection_tween.tween_callback(ring.queue_free).set_delay(0.4)

## Flash scanner bars red on failure
func flash_fail() -> void:
	if _fail_flash_tween and _fail_flash_tween.is_valid():
		_fail_flash_tween.kill()

	_fail_flash_tween = create_tween()
	_fail_flash_tween.set_parallel(true)

	if vertical_scanner_bar:
		vertical_scanner_bar.color = Color(1.0, 0.2, 0.2, 1.0)
		_fail_flash_tween.tween_property(vertical_scanner_bar, "color", Color(1.0, 0.75, 0.0, 0.8), 0.15)
	if horizontal_scanner_bar:
		horizontal_scanner_bar.color = Color(1.0, 0.2, 0.2, 1.0)
		_fail_flash_tween.tween_property(horizontal_scanner_bar, "color", Color(1.0, 0.75, 0.0, 0.8), 0.15)

func _on_harvest_success(_tier_item_id: String, _tier_name: String) -> void:
	# Harvest successful - UI will close automatically
	pass

func _on_harvest_failed() -> void:
	# Harvest failed - flash red and play SFX
	flash_fail()

func _on_ui_opened() -> void:
	visible = true
	_update_display()
	_create_resource_squares()

func _on_ui_closed() -> void:
	visible = false
	_clear_resource_squares()
