extends HarvestMiniGameState
class_name VerticalPhaseState

## Vertical phase state - vertical scan line is moving left-right.

func enter() -> void:
	mini_game.vertical_line_position = 0.0
	mini_game.vertical_moving_right = true
	mini_game.vertical_locked = false
	mini_game.set_process(true)

func process(delta: float) -> void:
	if mini_game.vertical_locked:
		return
	
	# Move vertical line continuously
	if mini_game.vertical_moving_right:
		mini_game.vertical_line_position += mini_game.scanner_speed * delta
		if mini_game.vertical_line_position >= 1.0:
			mini_game.vertical_line_position = 1.0
			mini_game.vertical_moving_right = false
	else:
		mini_game.vertical_line_position -= mini_game.scanner_speed * delta
		if mini_game.vertical_line_position <= 0.0:
			mini_game.vertical_line_position = 0.0
			mini_game.vertical_moving_right = true

func handle_input(action: String) -> void:
	if action == mini_game.input_action:
		# Lock vertical line and transition to horizontal phase
		mini_game.vertical_locked = true
		mini_game.change_state(HorizontalPhaseState.new(mini_game))

func update_visuals(ui: HarvestMiniGameUI) -> void:
	if not ui.scanner_container or not ui.vertical_scanner_bar:
		return
	
	var container_width = ui.scanner_container.size.x
	var container_height = ui.scanner_container.size.y
	
	# Update vertical scanner bar
	var vertical_x = mini_game.get_vertical_line_position() * container_width
	ui.vertical_scanner_bar.size.x = 2.0
	ui.vertical_scanner_bar.size.y = container_height  # Span full height
	ui.vertical_scanner_bar.position.x = vertical_x - ui.vertical_scanner_bar.size.x / 2.0
	ui.vertical_scanner_bar.position.y = 0.0
	
	# Visual feedback for vertical line
	if mini_game.vertical_locked:
		ui.vertical_scanner_bar.modulate.a = 1.0
	else:
		ui.vertical_scanner_bar.color = Color(1.0, 0.75, 0.0, 0.8)  # Amber when moving
		ui.vertical_scanner_bar.modulate.a = 0.8
	
	ui.vertical_scanner_bar.visible = true
	
	# Hide horizontal bar in vertical phase
	if ui.horizontal_scanner_bar:
		ui.horizontal_scanner_bar.visible = false

