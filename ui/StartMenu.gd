extends Control
class_name StartMenu

signal start_game
signal load_game

@onready var start_button: Button = $"CenterContainer/VBoxContainer/StartButton"
@onready var load_button: Button = $"CenterContainer/VBoxContainer/LoadButton"

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	if load_button:
		load_button.pressed.connect(_on_load_pressed)
		# Disable load button if no save exists
		load_button.disabled = not Save.save_exists()
	process_mode = Node.PROCESS_MODE_ALWAYS  # Always process so button works when paused

func _on_start_pressed() -> void:
	start_game.emit()
	visible = false

func _on_load_pressed() -> void:
	load_game.emit()
	visible = false

func show_menu() -> void:
	visible = true
	# Update load button state when menu is shown
	if load_button:
		load_button.disabled = not Save.save_exists()

