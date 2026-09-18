extends Control
class_name GateTerminal

## The Gate's own terminal, opened by GateDockedState while the ship sits in the cradle.
## No robot, no shopfront: the Titan's hardware talking to itself, and one row asking
## for the credits to bring this planet's Module online.
##
## UP/DOWN select, ENTER confirms, ESC leaves. Powering runs a short boot log the
## launch key skips, and then the hub comes back showing the Module online. Transit
## and refuelling rows belong to later slices.
## Built in code; the scene tree holds only the root.

signal terminal_closed
signal gate_powered(gate: Gate)

const WINDOW_SIZE := Vector2(560, 300)
const TEXT_SIZE := TerminalWindow.TEXT_SIZE
const SMALL_SIZE := TerminalWindow.SMALL_SIZE
const ROW_HEIGHT := 26.0
const RIGHT_WIDTH := 130.0
const MODULE_COUNT := 5

## Boot log pacing: characters a second, the beat between lines, and the hold at the end.
const BOOT_CHARS_PER_SEC := 27.0
const BOOT_LINE_GAP := 0.32
const BOOT_HOLD := 0.5

var gate: Gate = null
var gs: GameState = null

var _menu_items: Array[Dictionary] = []
var _selected_index := 0
var _booting := false
var _skip_boot := false

var _frame: TerminalWindow
var _status: Label
var _credits: Label
var _rows: VBoxContainer
var _log: VBoxContainer

func _ready() -> void:
	visible = false
	add_to_group("gate_terminal")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	gs = get_tree().get_first_node_in_group("game_state") as GameState
	_build_ui()

# --- Layout ------------------------------------------------------------------

func _build_ui() -> void:
	_frame = TerminalWindow.new(WINDOW_SIZE, TerminalWindow.spaced_title("GATE"), "")
	add_child(_frame)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_frame.body.add_child(col)

	_status = TerminalWindow.header("")
	col.add_child(_status)
	_credits = TerminalWindow.label("", SMALL_SIZE, Colors.PRIMARY_DIM)
	col.add_child(_credits)
	col.add_child(TerminalWindow.rule())

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	col.add_child(_rows)

	_log = VBoxContainer.new()
	_log.add_theme_constant_override("separation", 4)
	_log.visible = false
	col.add_child(_log)

	col.add_child(TerminalWindow.filler())

## One selectable row: `> LABEL            right`, dimmed when it can't be taken.
func _make_row(item: Dictionary, selected: bool) -> Control:
	var enabled: bool = item["enabled"]
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

	var text_color: Color = Colors.PRIMARY if enabled else Colors.PRIMARY_DIM
	var caret := TerminalWindow.label(">" if selected else " ", TEXT_SIZE, Colors.PRIMARY)
	caret.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caret)
	var name_label := TerminalWindow.label(item["label"], TEXT_SIZE, text_color)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	row.add_child(TerminalWindow.spacer())

	var right: String = item.get("right", "")
	if right != "":
		var right_label := TerminalWindow.label(right, TEXT_SIZE, item.get("right_color", text_color))
		right_label.custom_minimum_size.x = RIGHT_WIDTH
		right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(right_label)
	return panel

# --- Open / close ------------------------------------------------------------

func open(target: Gate) -> void:
	gate = target
	if not gs:
		gs = get_tree().get_first_node_in_group("game_state") as GameState
	_booting = false
	_skip_boot = false
	_clear(_log)
	_log.visible = false
	_show_hub(true)
	_selected_index = 0
	visible = true
	_refresh_hub()
	_frame.animate_in()

## True while the boot log is still typing itself out; the terminal takes no other
## input until it is done.
func is_booting() -> bool:
	return _booting

func close() -> void:
	if not visible:
		return
	visible = false
	_booting = false
	gate = null
	_clear(_log)
	terminal_closed.emit()

# --- Hub ---------------------------------------------------------------------

func _refresh_hub() -> void:
	var powered := gate != null and gate.is_powered()
	_status.text = TerminalWindow.spaced("MODULE ONLINE" if powered else "MODULE OFFLINE")
	_status.add_theme_color_override("font_color", Colors.TITAN if powered else Colors.PRIMARY)
	_credits.text = "TITAN INFLUENCE  %d / %d          CREDITS  %d CR" % [
		gs.titan_influence() if gs else 0, MODULE_COUNT, gs.credits if gs else 0]
	_frame.set_hint("UP/DN SELECT   ENTER CONFIRM   ESC LEAVE")

	_menu_items.clear()
	if powered:
		_menu_items.append({
			"enabled": false,
			"action": Callable(),
			"label": "GATE POWERED",
			"right": "ONLINE",
			"right_color": Colors.TITAN,
		})
	else:
		var affordable := gate != null and gs != null and gate.can_afford(gs)
		_menu_items.append({
			"enabled": affordable,
			"action": _on_power_pressed,
			"label": "POWER GATE",
			"right": "%d CR" % (gate.power_cost if gate else 0),
			"right_color": Colors.PRIMARY if affordable else Colors.DANGER,
		})
	_menu_items.append({"enabled": true, "action": close, "label": "DEPART", "right": "UNDOCK"})
	# Nothing left to do at a Gate that is already online but leave it
	_selected_index = _menu_items.size() - 1 if powered else clampi(_selected_index, 0, _menu_items.size() - 1)
	_refresh_rows()

## The boot log speaks for itself: the hub's readouts step aside while it runs rather
## than sit above it saying the Module is still offline.
func _show_hub(shown: bool) -> void:
	_status.visible = shown
	_credits.visible = shown
	_rows.visible = shown

func _refresh_rows() -> void:
	_clear(_rows)
	for i in _menu_items.size():
		_rows.add_child(_make_row(_menu_items[i], i == _selected_index))

# --- Input -------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed):
		return

	if _booting:
		# The launch key doubles as the skip key: nothing else undocks from in here.
		if (event as InputEventKey).keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
			_skip_boot = true
			get_viewport().set_input_as_handled()
		return

	match (event as InputEventKey).keycode:
		KEY_UP:
			_move_selection(-1)
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			_move_selection(1)
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			_activate_selection()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()

## Rows the player can't take stay selectable, so the cost of a Gate they can't
## afford yet can still be read off the terminal.
func _move_selection(direction: int) -> void:
	if _menu_items.is_empty():
		return
	var n := _menu_items.size()
	_selected_index = (_selected_index + direction + n) % n
	_refresh_rows()

func _activate_selection() -> void:
	if _selected_index < 0 or _selected_index >= _menu_items.size():
		return
	var item := _menu_items[_selected_index]
	if item["enabled"] and item["action"]:
		item["action"].call()

# --- Powering ----------------------------------------------------------------

func _on_power_pressed() -> void:
	if not gate or not gs or not gate.power(gs):
		return
	var powered_gate := gate
	gate_powered.emit(powered_gate)
	await _run_boot_log(gs.titan_influence())
	if visible and gate == powered_gate:
		_log.visible = false
		_show_hub(true)
		_selected_index = 0
		_refresh_hub()

## What the Gate says to itself as the Module wakes: three lines, typed, the last one
## in the Titan's own color. The launch key cuts it short.
func _run_boot_log(module: int) -> void:
	_booting = true
	_show_hub(false)
	_clear(_log)
	_log.visible = true
	_frame.set_hint(EventBus.action_prompt("SKIP"))

	var lines := [
		{"text": "POWER ........ OK", "color": Colors.PRIMARY},
		{"text": "LINK ......... OK", "color": Colors.PRIMARY},
		{"text": "MODULE %d/%d ... ONLINE" % [module, MODULE_COUNT], "color": Colors.TITAN},
	]
	for line in lines:
		if not visible:
			break
		await _type_line(line["text"], line["color"])
		if not _skip_boot and visible:
			await get_tree().create_timer(BOOT_LINE_GAP).timeout
	if visible and not _skip_boot:
		await get_tree().create_timer(BOOT_HOLD).timeout
	_booting = false

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
	typer.chars_per_second = BOOT_CHARS_PER_SEC
	label.add_child(typer)
	typer.setup(label)
	if _skip_boot:
		typer.show_immediate(text)
		return
	typer.type_text(text)
	while typer.is_typing():
		if _skip_boot or not visible:
			typer.skip()
			break
		await get_tree().process_frame

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
