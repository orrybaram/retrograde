extends HarvestMiniGameState
class_name CompleteState

## Complete state - both lines locked, calculating harvest.

var delay_timer: float = 0.0
var delay_duration: float = 1.0
var harvest_calculated: bool = false

func enter() -> void:
	delay_timer = 0.0
	harvest_calculated = false

func process(delta: float) -> void:
	if harvest_calculated:
		delay_timer += delta
		if delay_timer >= delay_duration:
			# Transition back to idle after delay
			mini_game.close_ui()
	else:
		# Calculate harvest amount and roll tier
		var harvest_amount = mini_game.calculate_harvest_amount()
		harvest_calculated = true

		var tier: TierData.Tier
		if harvest_amount > 0:
			tier = TierData.roll_tier(RNG.rng)
		else:
			# Botched — force Slag
			tier = TierData.Tier.SLAG

		var tier_item_id = TierData.get_item_id(tier)
		var tier_name = TierData.get_display_name(tier)
		mini_game.harvest_success.emit(tier_item_id, tier_name)

func handle_input(_action: String) -> void:
	# No input handling in complete state
	pass

func update_visuals(ui: HarvestMiniGameUI) -> void:
	if not ui.scanner_container or not ui.vertical_scanner_bar or not ui.horizontal_scanner_bar:
		return
	
	var container_width = ui.scanner_container.size.x
	var container_height = ui.scanner_container.size.y
	
	# Update vertical scanner bar (locked)
	var vertical_x = mini_game.get_vertical_line_position() * container_width
	ui.vertical_scanner_bar.size.x = 2.0
	ui.vertical_scanner_bar.size.y = container_height
	ui.vertical_scanner_bar.position.x = vertical_x - ui.vertical_scanner_bar.size.x / 2.0
	ui.vertical_scanner_bar.position.y = 0.0
	ui.vertical_scanner_bar.color = Color(0.0, 1.0, 0.0, 0.9)  # Green when locked
	ui.vertical_scanner_bar.modulate.a = 1.0
	ui.vertical_scanner_bar.visible = true
	
	# Update horizontal scanner bar (locked)
	var horizontal_y = mini_game.get_horizontal_line_position() * container_height
	ui.horizontal_scanner_bar.size.x = container_width
	ui.horizontal_scanner_bar.size.y = 2.0
	ui.horizontal_scanner_bar.position.x = 0.0
	ui.horizontal_scanner_bar.position.y = horizontal_y - ui.horizontal_scanner_bar.size.y / 2.0
	ui.horizontal_scanner_bar.color = Color(0.0, 1.0, 0.0, 0.9)  # Green when locked
	ui.horizontal_scanner_bar.modulate.a = 1.0
	ui.horizontal_scanner_bar.visible = true
