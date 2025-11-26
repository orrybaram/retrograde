extends Control
class_name HarvestMiniGameUI

## Simple terminal UI for resource harvesting.
## Shows resource info and waits for second scan press.

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var resource_label: Label = $MarginContainer/VBoxContainer/ResourceLabel
@onready var instruction_label: Label = $MarginContainer/VBoxContainer/InstructionLabel

var mini_game: HarvestMiniGame = null
var terminal_color: Color = Color(1.0, 0.75, 0.0)  # Amber/orange terminal color

func _ready() -> void:
	visible = false

func setup(mini_game_instance: HarvestMiniGame) -> void:
	mini_game = mini_game_instance
	
	if mini_game:
		mini_game.harvest_all.connect(_on_harvest_all)
		mini_game.ui_opened.connect(_on_ui_opened)
		mini_game.ui_closed.connect(_on_ui_closed)
		
		_update_display()

func cleanup() -> void:
	if mini_game:
		if mini_game.harvest_all.is_connected(_on_harvest_all):
			mini_game.harvest_all.disconnect(_on_harvest_all)
		if mini_game.ui_opened.is_connected(_on_ui_opened):
			mini_game.ui_opened.disconnect(_on_ui_opened)
		if mini_game.ui_closed.is_connected(_on_ui_closed):
			mini_game.ui_closed.disconnect(_on_ui_closed)
	
	mini_game = null
	visible = false

func _update_display() -> void:
	if not mini_game:
		return
	
	if title_label:
		title_label.text = "HARVEST TERMINAL"
	
	if resource_label:
		resource_label.text = "Resource: %s\nAmount: %d" % [mini_game.resource_kind, mini_game.resource_amount]
	
	if instruction_label:
		instruction_label.text = "Press SCAN to harvest"

func _on_harvest_all(_amount: int) -> void:
	# Harvest completed - UI will close automatically
	pass

func _on_ui_opened() -> void:
	visible = true
	_update_display()

func _on_ui_closed() -> void:
	visible = false
