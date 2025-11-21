extends Control
class_name GameOverMenu

signal relaunch_game

@onready var reason_label: Label = $"CenterContainer/VBoxContainer/ReasonLabel"
@onready var relaunch_button: Button = $"CenterContainer/VBoxContainer/RelaunchButton"

func _ready() -> void:
	relaunch_button.pressed.connect(_on_relaunch_pressed)
	process_mode = Node.PROCESS_MODE_ALWAYS  # Always process so button works when paused
	visible = false

func _on_relaunch_pressed() -> void:
	relaunch_game.emit()

func show_menu(reason: String) -> void:
	reason_label.text = reason
	visible = true

func hide_menu() -> void:
	visible = false

