extends HarvestMiniGameState
class_name HorizontalPhaseState

## Horizontal phase state - horizontal scan line is moving up-down.

func enter() -> void:
	mini_game.horizontal_line_position = 0.0
	mini_game.horizontal_moving_down = true
	mini_game.horizontal_locked = false

func process(delta: float) -> void:
	if mini_game.horizontal_locked:
		return
	
	# Move horizontal line continuously
	if mini_game.horizontal_moving_down:
		mini_game.horizontal_line_position += mini_game.scanner_speed * delta
		if mini_game.horizontal_line_position >= 1.0:
			mini_game.horizontal_line_position = 1.0
			mini_game.horizontal_moving_down = false
	else:
		mini_game.horizontal_line_position -= mini_game.scanner_speed * delta
		if mini_game.horizontal_line_position <= 0.0:
			mini_game.horizontal_line_position = 0.0
			mini_game.horizontal_moving_down = true

func handle_input(action: String) -> void:
	if action == mini_game.input_action:
		# Lock horizontal line and transition to complete phase
		mini_game.horizontal_locked = true
		mini_game.change_state(CompleteState.new(mini_game))

func update_visuals(ui: HarvestMiniGameUI) -> void:
	if not ui.scanner_container or not ui.vertical_scanner_bar or not ui.horizontal_scanner_bar:
		return
	
	var container_width = ui.scanner_container.size.x
	var container_height = ui.scanner_container.size.y
	
	# Update vertical scanner bar (locked, show at locked position)
	var vertical_x = mini_game.get_vertical_line_position() * container_width
	ui.vertical_scanner_bar.size.x = 2.0
	ui.vertical_scanner_bar.size.y = container_height
	ui.vertical_scanner_bar.position.x = vertical_x - ui.vertical_scanner_bar.size.x / 2.0
	ui.vertical_scanner_bar.position.y = 0.0
	ui.vertical_scanner_bar.color = Color(0.0, 1.0, 0.0, 0.9)  # Green when locked
	ui.vertical_scanner_bar.modulate.a = 1.0
	ui.vertical_scanner_bar.visible = true
	
	# Update horizontal scanner bar
	var horizontal_y = mini_game.get_horizontal_line_position() * container_height
	ui.horizontal_scanner_bar.size.x = container_width  # Span full width
	ui.horizontal_scanner_bar.size.y = 2.0  # Same thickness as vertical bar
	ui.horizontal_scanner_bar.position.x = 0.0
	ui.horizontal_scanner_bar.position.y = horizontal_y - ui.horizontal_scanner_bar.size.y / 2.0
	ui.horizontal_scanner_bar.color = Color(1.0, 0.75, 0.0, 0.8)  # Amber when moving
	ui.horizontal_scanner_bar.modulate.a = 0.8
	ui.horizontal_scanner_bar.visible = true

