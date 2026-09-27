extends Control
class_name CoreTerminal

## SR-7's dock terminal while the core is cold (docs/OPENING.md §5), opened by LandedState
## when the ship docks at a port nobody is awake to run. Not UNIT-7 and not the hub: the
## station's own maintenance console, on the core's standby battery, reporting what it can
## see and offering the one thing it can do.
##
## UP/DOWN select, ENTER confirms, ESC leaves. REBOOT CORE types a short log the launch key
## skips, then closes and asks for the reboot (`reboot_requested`); LandedState hands that
## to the core (CoreHousing.reboot) and the wake plays out on the station itself.
##
## Built in code; the scene tree holds only the root.

signal terminal_closed
## The player chose to reboot the core; the log has finished.
signal reboot_requested

const WINDOW_SIZE := Vector2(560, 300)
const TEXT_SIZE := TerminalWindow.TEXT_SIZE
const SMALL_SIZE := TerminalWindow.SMALL_SIZE
const ROW_HEIGHT := 26.0
const RIGHT_WIDTH := 130.0

## Log pacing: characters a second, the beat between lines, and the hold at the end.
const LOG_CHARS_PER_SEC := 27.0
const LOG_LINE_GAP := 0.32
const LOG_HOLD := 0.6

## What the console can see before anything is asked of it. Every line is true of a
## station that has just had its last piece put back.
const STATUS_LINES: Array[String] = [
	"AUX BATTERY ....... STANDBY",
	"HULL SECTIONS ..... SEATED",
	"DOCK ARM .......... LOCKED OUT",
	"CORE .............. COLD",
]

## What the core says to itself as it comes back: the placard's two operations, done for
## the player. The last line is the one the whole of Act 1 was for.
const REBOOT_LINES: Array[String] = [
	"SEAT .............. OK",
	"CYCLE ............. OK",
	"CORE .............. CAUGHT",
]

var _menu_items: Array[Dictionary] = []
var _selected_index := 0
var _running := false
var _skip := false

var _frame: TerminalWindow
var _status: Label
var _readout: VBoxContainer
var _rows: VBoxContainer
var _log: VBoxContainer

func _ready() -> void:
	visible = false
	add_to_group("core_terminal")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()

# --- Layout ------------------------------------------------------------------

func _build_ui() -> void:
	_frame = TerminalWindow.new(WINDOW_SIZE, TerminalWindow.spaced_title("SR-7 CORE"), "")
	add_child(_frame)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_frame.body.add_child(col)

	_status = TerminalWindow.header(TerminalWindow.spaced("CORE OFFLINE"))
	col.add_child(_status)
	col.add_child(TerminalWindow.rule())

	_readout = VBoxContainer.new()
	_readout.add_theme_constant_override("separation", 2)
	for line in STATUS_LINES:
		_readout.add_child(TerminalWindow.label(line, SMALL_SIZE, Colors.PRIMARY_DIM))
	col.add_child(_readout)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	col.add_child(_rows)

	_log = VBoxContainer.new()
	_log.add_theme_constant_override("separation", 4)
	_log.visible = false
	col.add_child(_log)

	col.add_child(TerminalWindow.filler())

## One selectable row: `> LABEL            right`.
func _make_row(item: Dictionary, selected: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = ROW_HEIGHT
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := TerminalWindow.box(Colors.PRIMARY_GHOST if selected else Color.TRANSPARENT, Colors.PRIMARY_DIM, 0)
	if selected:
		bg.border_width_left = 2
		bg.border_color = Colors.PRIMARY
	bg.content_margin_left = 10
	bg.content_margin_right = 10
	panel.add_theme_stylebox_override("panel", bg)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var caret := TerminalWindow.label(">" if selected else " ", TEXT_SIZE, Colors.PRIMARY)
	caret.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caret)
	var name_label := TerminalWindow.label(item["label"], TEXT_SIZE, Colors.PRIMARY)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	row.add_child(TerminalWindow.spacer())
	var right := TerminalWindow.label(item["right"], TEXT_SIZE, Colors.PRIMARY_DIM)
	right.custom_minimum_size.x = RIGHT_WIDTH
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	return panel

# --- Open / close ------------------------------------------------------------

func open() -> void:
	_running = false
	_skip = false
	_clear(_log)
	_log.visible = false
	_show_menu(true)
	_menu_items = [
		{"action": _on_reboot_pressed, "label": "REBOOT CORE", "right": ""},
		{"action": close, "label": "DEPART", "right": "UNDOCK"},
	]
	_selected_index = 0
	_refresh_rows()
	_frame.set_hint(Controls.menu_hint("CONFIRM", "LEAVE"))
	visible = true
	_frame.animate_in()

## True while the reboot log is typing itself out; the terminal takes no other input.
func is_running() -> bool:
	return _running

func close() -> void:
	if not visible:
		return
	visible = false
	_running = false
	_clear(_log)
	terminal_closed.emit()

func _show_menu(shown: bool) -> void:
	_readout.visible = shown
	_rows.visible = shown

func _refresh_rows() -> void:
	_clear(_rows)
	for i in _menu_items.size():
		_rows.add_child(_make_row(_menu_items[i], i == _selected_index))

# --- Input -------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not event.is_pressed():
		return
	var action := Controls.menu_action(event)

	if _running:
		if action in [&"menu_accept", &"menu_back"] or event.is_action_pressed(&"action"):
			_skip = true
			get_viewport().set_input_as_handled()
		return

	match action:
		&"menu_up":
			_move_selection(-1)
			get_viewport().set_input_as_handled()
		&"menu_down":
			_move_selection(1)
			get_viewport().set_input_as_handled()
		&"menu_accept":
			_activate_selection()
			get_viewport().set_input_as_handled()
		&"menu_back":
			close()
			get_viewport().set_input_as_handled()

func _move_selection(direction: int) -> void:
	var n := _menu_items.size()
	if n == 0:
		return
	_selected_index = (_selected_index + direction + n) % n
	_refresh_rows()

func _activate_selection() -> void:
	if _selected_index < 0 or _selected_index >= _menu_items.size():
		return
	var action: Callable = _menu_items[_selected_index]["action"]
	if action.is_valid():
		action.call()

# --- Reboot ------------------------------------------------------------------

func _on_reboot_pressed() -> void:
	await _run_log()
	if not visible:
		return
	close()
	reboot_requested.emit()

func _run_log() -> void:
	_running = true
	_show_menu(false)
	_clear(_log)
	_log.visible = true
	_frame.set_hint(EventBus.inline_key_prompt("action", "SKIP"))
	for i in REBOOT_LINES.size():
		if not visible:
			break
		var last := i == REBOOT_LINES.size() - 1
		await _type_line(REBOOT_LINES[i], Colors.CREAM if last else Colors.PRIMARY)
		if not _skip and visible:
			await get_tree().create_timer(LOG_LINE_GAP).timeout
	if visible and not _skip:
		await get_tree().create_timer(LOG_HOLD).timeout
	_running = false

func _type_line(text: String, color: Color) -> void:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", TEXT_SIZE)
	label.add_theme_color_override("default_color", color)
	_log.add_child(label)

	var typer := Typewriter.new()
	typer.chars_per_second = LOG_CHARS_PER_SEC
	label.add_child(typer)
	typer.setup(label)
	if _skip:
		typer.show_immediate(text)
		return
	typer.type_text(text)
	while typer.is_typing():
		if _skip or not visible:
			typer.skip()
			break
		await get_tree().process_frame

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
