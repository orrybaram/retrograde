extends Control
class_name LoadingScreen

## Loading screen displayed during solar system generation

@onready var terminal_label: RichTextLabel = $"VBoxContainer/TerminalLabel"

var _animation_tween: Tween = null
@export var line_count: int = 150
@export var duration: float = 3.0  # Longer duration to cover resource spawning
## Number of lines to display in the terminal animation

var _boot_messages: Array[String] = [
	"Initializing navigation systems",
	"Loading stellar database",
	"Calibrating sensors",
	"Establishing communication protocols",
	"Scanning for celestial bodies",
	"Generating orbital calculations",
	"Finalizing generation",
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Always process so it works when paused
	visible = false

func show_loading() -> void:
	visible = true
	_start_terminal_animation()

func hide_loading() -> void:
	_stop_terminal_animation()
	visible = false

func _start_terminal_animation() -> void:
	if not terminal_label:
		return
	
	# Stop any existing animation
	_stop_terminal_animation()
	
	# Clear terminal
	terminal_label.text = ""
	
	# Calculate timing: up to 2 seconds total
	var total_duration = duration
	var delay_per_line = total_duration / line_count
	
	# Start animation
	_animation_tween = create_tween()
	_animation_tween.set_parallel(false)
	
	# Calculate how many lines each message should get
	var messages_count = _boot_messages.size()
	var lines_per_message = int(line_count / float(messages_count))
	var remaining_lines = line_count % messages_count
	
	var line_index = 0
	
	# Assign messages sequentially, each message gets its share of lines
	for message_idx in range(messages_count):
		var message = _boot_messages[message_idx]
		var lines_for_this_message = lines_per_message
		
		# Distribute remaining lines to first messages
		if message_idx < remaining_lines:
			lines_for_this_message += 1
		
		# Add all lines for this message
		for j in range(lines_for_this_message):
			var progress = int(line_index + 1) / float(line_count) * 100  # Progress from 1% to 100%
			if progress > 100:
				progress = 100  # Cap at 100%
			
			# Add a little randomness to the delay
			var delay = delay_per_line + randf_range(-delay_per_line * 2.5, delay_per_line * 2.5)
			_animation_tween.tween_callback(_add_terminal_line.bind(message, progress)).set_delay(delay)
			line_index += 1

func _add_terminal_line(message: String, progress: int) -> void:
	if not terminal_label:
		return
	
	var padded_message = message.rpad(50, '.')
	var line_text = "[color=#FFBF00]%s[/color][color=#00FF00][%d%%][/color]" % [padded_message, progress]
	
	if terminal_label.text != "":
		terminal_label.text += "\n"
	terminal_label.text += line_text
	
	# Scroll to bottom
	terminal_label.scroll_to_line(terminal_label.get_line_count() - 1)

func _stop_terminal_animation() -> void:
	if _animation_tween:
		_animation_tween.kill()
		_animation_tween = null
	
	if terminal_label:
		terminal_label.text = ""

func set_message(text: String) -> void:
	# Legacy method - can be used to set custom message if needed
	if terminal_label:
		terminal_label.text = text
