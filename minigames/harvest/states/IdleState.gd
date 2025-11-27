extends HarvestMiniGameState
class_name IdleState

## Idle state - game is closed, not active.

func enter() -> void:
	mini_game.set_process(false)

func process(_delta: float) -> void:
	# No processing needed in idle state
	pass

func handle_input(_action: String) -> void:
	# No input handling in idle state
	pass

func update_visuals(ui: HarvestMiniGameUI) -> void:
	# Hide all scanner bars in idle state
	if ui.vertical_scanner_bar:
		ui.vertical_scanner_bar.visible = false
	if ui.horizontal_scanner_bar:
		ui.horizontal_scanner_bar.visible = false

