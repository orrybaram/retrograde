extends Control
class_name GameOverMenu

signal relaunch_game

@onready var fade_overlay: ColorRect = $"FadeOverlay"
@onready var terminal_output: RichTextLabel = $"TerminalOutput"
@onready var cursor_label: Label = $"CursorLabel"

var death_count: int = 0
var reason: String = ""
var fade_duration: float = 0.75  # Seconds to fade to black
var fade_timer: float = 0.0
var is_fading: bool = false
var terminal_shown: bool = false
var cursor_blink_timer: float = 0.0
var cursor_blink_interval: float = 0.6
var cursor_visible: bool = true

# Typewriter effect variables
var is_typing: bool = false
var full_text_lines: Array = []  # Array of strings (one per line)
var current_line_index: int = 0
var current_char_index: int = 0
var typing_speed: float = 0.0075  # Seconds per character (death message)
var boot_typing_speed: float = 0.001875  # Seconds per character (4x faster for boot)
var typing_timer: float = 0.0
var displayed_text: String = ""
var typing_complete: bool = false

# Boot sequence variables
var is_booting: bool = false
var boot_complete: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game_over_menu")
	visible = false

	# Start with fade overlay transparent
	if fade_overlay:
		fade_overlay.color = Color(0, 0, 0, 0)
		fade_overlay.visible = false

	if terminal_output:
		terminal_output.visible = false

	if cursor_label:
		cursor_label.visible = false

func _process(delta: float) -> void:
	if not visible:
		return

	# Handle fade-in
	if is_fading:
		fade_timer += delta
		var alpha = min(fade_timer / fade_duration, 1.0)
		if fade_overlay:
			fade_overlay.color = Color(0, 0, 0, alpha)

		# When fade completes, start typewriter effect
		if alpha >= 1.0:
			is_fading = false
			_start_typing()

	# Handle typewriter effect
	if is_typing:
		typing_timer += delta

		# Use faster speed for boot sequence, normal speed for death message
		var current_speed = boot_typing_speed if is_booting else typing_speed

		# Type characters at the specified speed
		while typing_timer >= current_speed:
			typing_timer -= current_speed
			_type_next_character()

	# Handle cursor blinking (only after typing is complete)
	if typing_complete and terminal_output:
		cursor_blink_timer += delta
		if cursor_blink_timer >= cursor_blink_interval:
			cursor_blink_timer = 0.0
			cursor_visible = !cursor_visible
			# Toggle cursor by appending/removing it from the text
			if cursor_visible:
				terminal_output.text = displayed_text + "_"
			else:
				terminal_output.text = displayed_text

func _input(event: InputEvent) -> void:
	if not visible or is_fading:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			# If currently typing, skip to end immediately
			if is_typing:
				_skip_typing()
				get_viewport().set_input_as_handled()
			# If typing is done, start boot sequence
			elif typing_complete and not is_booting and not boot_complete:
				_start_boot_sequence()
				get_viewport().set_input_as_handled()

func show_menu(death_reason: String) -> void:
	reason = death_reason

	# Get death count from GameState
	var gs = get_tree().get_first_node_in_group("game_state") as GameState
	if gs:
		death_count = gs.death_count

	visible = true
	is_fading = true
	terminal_shown = false
	fade_timer = 0.0
	cursor_blink_timer = 0.0
	cursor_visible = true

	# Reset typewriter state
	is_typing = false
	typing_complete = false
	current_line_index = 0
	current_char_index = 0
	typing_timer = 0.0
	displayed_text = ""
	full_text_lines.clear()

	# Reset boot sequence state
	is_booting = false
	boot_complete = false

	# Show fade overlay and start fading
	if fade_overlay:
		fade_overlay.visible = true
		fade_overlay.color = Color(0, 0, 0, 0)

	# Hide terminal output initially
	if terminal_output:
		terminal_output.visible = false
		terminal_output.text = ""
	if cursor_label:
		cursor_label.visible = false

func hide_menu() -> void:
	visible = false
	is_fading = false
	terminal_shown = false
	is_typing = false
	typing_complete = false
	is_booting = false
	boot_complete = false

	if fade_overlay:
		fade_overlay.visible = false
	if terminal_output:
		terminal_output.visible = false
		terminal_output.text = ""
	if cursor_label:
		cursor_label.visible = false

func _start_typing() -> void:
	if not terminal_output:
		return

	# Build array of lines to type out
	full_text_lines.clear()

	if reason == "Tractor Beam":
		# Tractor beam rescue messaging (no skull, no death count)
		full_text_lines.append("    /  \\")
		full_text_lines.append("   / || \\")
		full_text_lines.append("  /  ||  \\")
		full_text_lines.append(" /   ||   \\")
		full_text_lines.append("/    ||    \\")
		full_text_lines.append("     ||")
		full_text_lines.append("     /\\")
		full_text_lines.append("    /  \\")
		full_text_lines.append("")
		full_text_lines.append("> FUEL RESERVES DEPLETED")
		full_text_lines.append("> TRACTOR BEAM LOCK DETECTED")
		full_text_lines.append("> INITIATING EMERGENCY DOCK SEQUENCE...")
		full_text_lines.append("")
		full_text_lines.append("")
		full_text_lines.append("> CARGO AND CREDITS PRESERVED")
		full_text_lines.append("")
		full_text_lines.append("")
		full_text_lines.append("")
		full_text_lines.append("> PRESS [ENTER] TO CONTINUE")
	else:
		# ASCII skull and crossbones
		full_text_lines.append("    ___")
		full_text_lines.append("   /   \\")
		full_text_lines.append("  | X X |")
		full_text_lines.append("  |  ^  |")
		full_text_lines.append("  | \\_/ |")
		full_text_lines.append("   \\___/")
		full_text_lines.append("   _|_|_")
		full_text_lines.append("  / | | \\")
		full_text_lines.append("")

		# System failure message based on death reason
		full_text_lines.append("> SYSTEM FAILURE DETECTED")

		if reason == "Ship Destroyed":
			full_text_lines.append("> HULL INTEGRITY: 0%")
			full_text_lines.append("> CRITICAL STRUCTURAL DAMAGE")
		elif reason == "Out of Fuel":
			full_text_lines.append("> FUEL RESERVES DEPLETED")
			full_text_lines.append("> LIFE SUPPORT OFFLINE")
		else:
			full_text_lines.append("> CATASTROPHIC FAILURE")

		full_text_lines.append("> INITIATING EMERGENCY PROTOCOLS...")
		full_text_lines.append("")
		full_text_lines.append("")
		full_text_lines.append("> TOTAL DEATHS: %d" % death_count)
		full_text_lines.append("")
		full_text_lines.append("")
		full_text_lines.append("")
		full_text_lines.append("> PRESS [ENTER] TO CONTINUE")

	# Start typing
	current_line_index = 0
	current_char_index = 0
	displayed_text = ""
	is_typing = true
	typing_complete = false

	# Show terminal output (empty initially)
	terminal_output.text = ""
	terminal_output.visible = true
	terminal_shown = true

	# Hide the separate cursor label (we use text-based cursor now)
	if cursor_label:
		cursor_label.visible = false

func _skip_typing() -> void:
	if not is_typing or not terminal_output:
		return

	# Render all remaining text immediately
	while current_line_index < full_text_lines.size():
		var line = full_text_lines[current_line_index]
		displayed_text += line.substr(current_char_index) + "\n"
		current_char_index = 0
		current_line_index += 1

	if is_booting:
		_finish_boot_sequence()
	else:
		_finish_typing()

func _type_next_character() -> void:
	if not is_typing or current_line_index >= full_text_lines.size():
		return

	var current_line = full_text_lines[current_line_index]

	# Type one character from the current line
	if current_char_index < current_line.length():
		displayed_text += current_line[current_char_index]
		current_char_index += 1
		terminal_output.text = displayed_text
	else:
		# Finished current line, move to next
		displayed_text += "\n"
		terminal_output.text = displayed_text
		current_line_index += 1
		current_char_index = 0

		# Check if we've typed all lines
		if current_line_index >= full_text_lines.size():
			if is_booting:
				_finish_boot_sequence()
			else:
				_finish_typing()

func _finish_typing() -> void:
	is_typing = false
	typing_complete = true
	cursor_visible = true

	# Start with cursor visible (it will blink in _process)
	if terminal_output:
		terminal_output.text = displayed_text + "_"

func _start_boot_sequence() -> void:
	if not terminal_output:
		return

	# Append to existing text (don't clear)
	# Remove the blinking cursor from displayed_text if it's there
	displayed_text = displayed_text.rstrip("_")

	# Add spacing before boot messages
	displayed_text += "\n\n"
	full_text_lines.clear()

	# Boot sequence messages
	if reason == "Tractor Beam":
		full_text_lines.append("> TRACTOR BEAM ENGAGED...")
		full_text_lines.append("")
		full_text_lines.append("> PULLING VESSEL TO DOCK...............[OK]")
		full_text_lines.append("> REFUELING TANKS......................[OK]")
		full_text_lines.append("> RESTORING HULL INTEGRITY.............[OK]")
		full_text_lines.append("> CALIBRATING SENSORS..................[OK]")
		full_text_lines.append("> DOCKING CLAMPS SECURED...............[OK]")
		full_text_lines.append("")
		full_text_lines.append("> EMERGENCY DOCK COMPLETE")
		full_text_lines.append("> SYSTEMS ONLINE")
	else:
		full_text_lines.append("> REBOOTING SYSTEMS...")
		full_text_lines.append("")
		full_text_lines.append("> INITIALIZING CORE FUNCTIONS.........[OK]")
		full_text_lines.append("> LOADING NAVIGATION SYSTEMS...........[OK]")
		full_text_lines.append("> RESTORING HULL INTEGRITY.............[OK]")
		full_text_lines.append("> REFUELING TANKS......................[OK]")
		full_text_lines.append("> CALIBRATING SENSORS..................[OK]")
		full_text_lines.append("> ESTABLISHING ORBITAL LINK............[OK]")
		full_text_lines.append("")
		full_text_lines.append("> SYSTEM READY")
		full_text_lines.append("> LAUNCHING...")

	# Reset typing state and start boot sequence
	current_line_index = 0
	current_char_index = 0
	is_typing = true
	typing_complete = false
	is_booting = true
	typing_timer = 0.0

	# Update terminal with current text (removes cursor)
	terminal_output.text = displayed_text

func _finish_boot_sequence() -> void:
	is_typing = false
	is_booting = false
	boot_complete = true

	# Wait a brief moment then relaunch
	await get_tree().create_timer(0.5).timeout
	relaunch_game.emit()

