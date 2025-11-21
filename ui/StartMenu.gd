extends Control
class_name StartMenu

signal start_game

@onready var start_button: Button = $"CenterContainer/VBoxContainer/StartButton"

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	process_mode = Node.PROCESS_MODE_ALWAYS  # Always process so button works when paused

func _on_start_pressed() -> void:
	start_game.emit()
	visible = false

func show_menu() -> void:
	visible = true

