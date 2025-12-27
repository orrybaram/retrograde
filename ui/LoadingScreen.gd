extends Control
class_name LoadingScreen

## Loading screen displayed during solar system generation

@onready var message_label: Label = $"CenterContainer/VBoxContainer/MessageLabel"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Always process so it works when paused
	visible = false

func show_loading() -> void:
	visible = true

func hide_loading() -> void:
	visible = false

func set_message(text: String) -> void:
	if message_label:
		message_label.text = text

