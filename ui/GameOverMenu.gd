extends Control
class_name GameOverMenu

signal relaunch_game

@onready var fade_overlay: ColorRect = $"FadeOverlay"
@onready var terminal_output: RichTextLabel = $"TerminalOutput"
@onready var cursor_label: Label = $"CursorLabel"

var death_count: int = 0
var reason: String = ""
var fade_duration: float = 0.75
var fade_timer: float = 0.0
var is_fading: bool = false

var cursor_blink_timer: float = 0.0
var cursor_blink_interval: float = 0.6
var cursor_visible: bool = true

var _typewriter: Typewriter = null
var _boot_pending: bool = false
var _boot_started: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game_over_menu")
	visible = false

	if fade_overlay:
		fade_overlay.color = Color(0, 0, 0, 0)
		fade_overlay.visible = false

	if terminal_output:
		terminal_output.visible = false

	if cursor_label:
		cursor_label.visible = false

	_typewriter = Typewriter.new()
	_typewriter.chars_per_second = 133.0
	_typewriter.setup(terminal_output)
	_typewriter.typing_finished.connect(_on_typing_finished)
	add_child(_typewriter)

func _process(delta: float) -> void:
	if not visible:
		return

	if is_fading:
		fade_timer += delta
		var alpha = min(fade_timer / fade_duration, 1.0)
		if fade_overlay:
			fade_overlay.color = Color(0, 0, 0, alpha)

		if alpha >= 1.0:
			is_fading = false
			_start_typing()

	# Cursor blinking after typing finishes (before boot)
	if _boot_pending and not _typewriter.is_typing() and terminal_output:
		cursor_blink_timer += delta
		if cursor_blink_timer >= cursor_blink_interval:
			cursor_blink_timer = 0.0
			cursor_visible = !cursor_visible
			if cursor_visible:
				terminal_output.text = _typewriter._full_text + "_"
				terminal_output.visible_characters = -1
			else:
				terminal_output.text = _typewriter._full_text
				terminal_output.visible_characters = -1

func _input(event: InputEvent) -> void:
	if not visible or is_fading:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if _typewriter.is_typing():
				_typewriter.skip()
				get_viewport().set_input_as_handled()
			elif _boot_pending and not _boot_started:
				_boot_pending = false
				_boot_started = true
				_start_boot_sequence()
				get_viewport().set_input_as_handled()

func show_menu(death_reason: String) -> void:
	reason = death_reason

	var gs = get_tree().get_first_node_in_group("game_state") as GameState
	if gs:
		death_count = gs.death_count

	visible = true
	is_fading = true
	fade_timer = 0.0
	cursor_blink_timer = 0.0
	cursor_visible = true
	_boot_pending = false
	_boot_started = false

	if fade_overlay:
		fade_overlay.visible = true
		fade_overlay.color = Color(0, 0, 0, 0)

	if terminal_output:
		terminal_output.visible = false
		terminal_output.text = ""
	if cursor_label:
		cursor_label.visible = false

func hide_menu() -> void:
	visible = false
	is_fading = false
	_boot_pending = false
	_boot_started = false

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

	var lines: Array[String] = []

	if reason == "Tractor Beam":
		lines.append("    /  \\")
		lines.append("   / || \\")
		lines.append("  /  ||  \\")
		lines.append(" /   ||   \\")
		lines.append("/    ||    \\")
		lines.append("     ||")
		lines.append("     /\\")
		lines.append("    /  \\")
		lines.append("")
		lines.append("> FUEL RESERVES DEPLETED")
		lines.append("> TRACTOR BEAM LOCK DETECTED")
		lines.append("> INITIATING EMERGENCY DOCK SEQUENCE...")
		lines.append("")
		lines.append("")
		lines.append("> CARGO AND CREDITS PRESERVED")
		lines.append("")
		lines.append("")
		lines.append("")
		lines.append("> PRESS [ENTER] TO CONTINUE")
	else:
		lines.append("    ___")
		lines.append("   /   \\")
		lines.append("  | X X |")
		lines.append("  |  ^  |")
		lines.append("  | \\_/ |")
		lines.append("   \\___/")
		lines.append("   _|_|_")
		lines.append("  / | | \\")
		lines.append("")

		lines.append("> SYSTEM FAILURE DETECTED")

		if reason == "Ship Destroyed":
			lines.append("> HULL INTEGRITY: 0%")
			lines.append("> CRITICAL STRUCTURAL DAMAGE")
		elif reason == "Out of Fuel":
			lines.append("> FUEL RESERVES DEPLETED")
			lines.append("> LIFE SUPPORT OFFLINE")
		else:
			lines.append("> CATASTROPHIC FAILURE")

		lines.append("> INITIATING EMERGENCY PROTOCOLS...")
		lines.append("")
		lines.append("")
		lines.append("> TOTAL DEATHS: %d" % death_count)
		lines.append("")
		lines.append("")
		lines.append("")
		lines.append("> PRESS [ENTER] TO CONTINUE")

	terminal_output.text = ""
	terminal_output.visible = true

	if cursor_label:
		cursor_label.visible = false

	_typewriter.type_text("\n".join(lines))

func _on_typing_finished() -> void:
	if _boot_started:
		# Boot sequence done, relaunch
		await get_tree().create_timer(0.5).timeout
		relaunch_game.emit()
	else:
		# Death message done, wait for ENTER
		_boot_pending = true
		cursor_blink_timer = 0.0
		cursor_visible = true

func _start_boot_sequence() -> void:
	if not terminal_output:
		return

	var boot_lines: Array[String] = []
	boot_lines.append("")
	boot_lines.append("")

	if reason == "Tractor Beam":
		boot_lines.append("> TRACTOR BEAM ENGAGED...")
		boot_lines.append("")
		boot_lines.append("> PULLING VESSEL TO DOCK...............[OK]")
		boot_lines.append("> REFUELING TANKS......................[OK]")
		boot_lines.append("> RESTORING HULL INTEGRITY.............[OK]")
		boot_lines.append("> CALIBRATING SENSORS..................[OK]")
		boot_lines.append("> DOCKING CLAMPS SECURED...............[OK]")
		boot_lines.append("")
		boot_lines.append("> EMERGENCY DOCK COMPLETE")
		boot_lines.append("> SYSTEMS ONLINE")
	else:
		boot_lines.append("> REBOOTING SYSTEMS...")
		boot_lines.append("")
		boot_lines.append("> INITIALIZING CORE FUNCTIONS.........[OK]")
		boot_lines.append("> LOADING NAVIGATION SYSTEMS...........[OK]")
		boot_lines.append("> RESTORING HULL INTEGRITY.............[OK]")
		boot_lines.append("> REFUELING TANKS......................[OK]")
		boot_lines.append("> CALIBRATING SENSORS..................[OK]")
		boot_lines.append("> ESTABLISHING ORBITAL LINK............[OK]")
		boot_lines.append("")
		boot_lines.append("> SYSTEM READY")
		boot_lines.append("> LAUNCHING...")

	# Use faster speed for boot sequence
	_typewriter.chars_per_second = 533.0
	_typewriter.append_text("\n".join(boot_lines))
