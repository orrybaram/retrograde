class_name ControlsUI
extends CanvasLayer

## The CONTROLS screen, opened from the start and pause menus: every action in
## `Controls.ACTIONS` with its two keyboard and two pad bindings, grouped as listed there.
## UP/DOWN pick a row, LEFT/RIGHT a column, CONFIRM listens for the new input (ESC or
## START cancels), CLEAR empties the slot, BACK closes. PAUSE and the MENUS keys are
## shown dimmed but can't be changed. The last row puts every default back.
##
## A new input another action already uses (live at the same time) swaps over: that
## action takes this slot's old one, and the status line says so.

signal closed

const WINDOW_SIZE := Vector2(880, 580)
## Over the start and pause menus, whatever size their own nodes are.
const LAYER := 100
const TEXT_SIZE := TerminalWindow.TEXT_SIZE
const NAME_WIDTH := 20
const CELL_WIDTH := 12
const KEY := 0
const PAD := 1
## [device, slot, heading] per column, left to right.
const COLUMNS := [[KEY, 0, "KEY"], [KEY, 1, "ALT KEY"], [PAD, 0, "PAD"], [PAD, 1, "ALT PAD"]]
const RESET := &"__reset"

var _frame: TerminalWindow
var _scroll: ScrollContainer
var _list: VBoxContainer
var _status: Label
## One entry per line: {"group": name} or {"id": action} or {"id": RESET}.
var _entries: Array[Dictionary] = []
var _lines: Array[RichTextLabel] = []
var _row := 0
var _col := 0
var _capturing := false


func _ready() -> void:
	visible = false
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("controls_ui")
	_build()
	Controls.device_changed.connect(func(_pad: bool) -> void: _refresh_hint())


func open() -> void:
	visible = true
	_capturing = false
	_row = _first_selectable()
	_col = 0
	_status.text = ""
	_redraw()
	_refresh_hint()
	_frame.animate_in()


func close() -> void:
	visible = false
	_capturing = false
	closed.emit()


func is_capturing() -> bool:
	return _capturing


# --- Layout ------------------------------------------------------------------

func _build() -> void:
	_frame = TerminalWindow.new(WINDOW_SIZE, TerminalWindow.spaced_title("CONTROLS"), "")
	add_child(_frame)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_frame.body.add_child(col)

	var heading := "  " + _pad_to("", NAME_WIDTH)
	for c in COLUMNS:
		heading += _pad_to(c[2], CELL_WIDTH)
	col.add_child(TerminalWindow.label(heading, TEXT_SIZE, Colors.PRIMARY_DIM))
	col.add_child(TerminalWindow.rule())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	_scroll.add_child(_list)

	col.add_child(TerminalWindow.rule())
	_status = TerminalWindow.label("", TEXT_SIZE, Colors.PRIMARY)
	_status.custom_minimum_size.y = 14
	col.add_child(_status)

	for group in Controls.GROUPS:
		_add_line({"group": group})
		for a in Controls.ACTIONS:
			if a["group"] == group:
				_add_line({"id": a["id"]})
	_add_line({"group": ""})
	_add_line({"id": RESET})


func _add_line(entry: Dictionary) -> void:
	var line := RichTextLabel.new()
	line.bbcode_enabled = true
	line.fit_content = true
	line.scroll_active = false
	line.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_size_override("normal_font_size", TEXT_SIZE)
	line.add_theme_color_override("default_color", Colors.PRIMARY)
	_list.add_child(line)
	_entries.append(entry)
	_lines.append(line)


func _redraw() -> void:
	for i in _entries.size():
		_lines[i].text = _line_text(i)
	_scroll.ensure_control_visible.call_deferred(_lines[_row])


func _line_text(i: int) -> String:
	var entry := _entries[i]
	var selected := i == _row
	if entry.has("group"):
		var g: String = entry["group"]
		return "" if g == "" else _color(TerminalWindow.spaced(g), Colors.PRIMARY_DIM)
	if entry["id"] == RESET:
		return (_color(">", Colors.PRIMARY) + " " if selected else "  ") + "RESET TO DEFAULTS"
	var id: StringName = entry["id"]
	var fixed := Controls.is_fixed(id)
	var base := Colors.PRIMARY_DIM if fixed else Colors.PRIMARY
	var text := (_color(">", Colors.PRIMARY) + " ") if selected else "  "
	text += _color(_esc(_pad_to(Controls.info(id)["label"], NAME_WIDTH)), base)
	for c in COLUMNS.size():
		var spec: Array = COLUMNS[c]
		var ev := Controls.event_at(id, spec[0], spec[1])
		var cell := Controls.event_label(ev) if ev else "--"
		if selected and c == _col and _capturing:
			cell = "PRESS..."
		cell = _pad_to(cell, CELL_WIDTH - 1)
		if selected and c == _col and not fixed:
			text += "[bgcolor=#%s]%s[/bgcolor] " % [Colors.hex(Colors.PRIMARY), _color(_esc(cell), Colors.SPACE_BG)]
		else:
			text += _color(_esc(cell), base if ev else Colors.PRIMARY_DIM) + " "
	return text


func _refresh_hint() -> void:
	var hint := "%s SELECT   %s SLOT   %s REBIND   %s CLEAR   %s BACK" % [
		Controls.nav_label(), "D-PAD" if Controls.using_pad else "LEFT/RIGHT",
		Controls.label(&"menu_accept"), Controls.label(&"menu_clear"), Controls.label(&"menu_back")]
	if _capturing:
		hint = "PRESS THE NEW %s   ESC / START CANCEL" % ("PAD INPUT" if _kind() == PAD else "KEY")
	_frame.set_hint(hint)


static func _color(text: String, color: Color) -> String:
	return "[color=#%s]%s[/color]" % [Colors.hex(color), text]


static func _esc(text: String) -> String:
	return text.replace("[", "[lb]")


static func _pad_to(text: String, width: int) -> String:
	return text.substr(0, width).rpad(width)


# --- Input -------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Everything stops here while the screen is up, the menu behind it included.
	get_viewport().set_input_as_handled()
	if _capturing:
		_capture(event)
		return
	match Controls.menu_action(event):
		&"menu_up":
			_move_row(-1)
		&"menu_down":
			_move_row(1)
		&"menu_left":
			_move_col(-1)
		&"menu_right":
			_move_col(1)
		&"menu_accept":
			_activate()
		&"menu_clear":
			_clear()
		&"menu_back":
			close()


func _capture(event: InputEvent) -> void:
	if Controls.cancels_capture(event):
		_end_capture("")
		return
	var binding := Controls.capture(event, _kind())
	if binding == null:
		return
	var id := _selected_id()
	var result := Controls.rebind(id, _kind(), _slot(), binding)
	var what: String = Controls.info(id)["label"]
	var input := Controls.event_label(binding)
	if result["blocked"] != &"":
		_end_capture("%s IS KEPT FOR %s" % [input, Controls.info(result["blocked"])["label"]])
	elif result["swapped"] != &"":
		_end_capture("%s NOW ON %s   %s TOOK ITS OLD INPUT" % [what, input, Controls.info(result["swapped"])["label"]])
	else:
		_end_capture("%s NOW ON %s" % [what, input])


func _end_capture(message: String) -> void:
	_capturing = false
	_status.text = message
	_redraw()
	_refresh_hint()


func _activate() -> void:
	var id := _selected_id()
	if id == RESET:
		Controls.reset_to_defaults()
		_status.text = "DEFAULTS RESTORED"
		_redraw()
		return
	if Controls.is_fixed(id):
		return
	_capturing = true
	_status.text = ""
	_redraw()
	_refresh_hint()


func _clear() -> void:
	var id := _selected_id()
	if id == RESET or Controls.is_fixed(id):
		return
	Controls.clear_binding(id, _kind(), _slot())
	_status.text = "%s CLEARED" % Controls.info(id)["label"]
	_redraw()


func _move_row(direction: int) -> void:
	var i := _row
	for _step in _entries.size():
		i = (i + direction + _entries.size()) % _entries.size()
		if _selectable(i):
			break
	_row = i
	_status.text = ""
	_redraw()


func _move_col(direction: int) -> void:
	_col = clampi(_col + direction, 0, COLUMNS.size() - 1)
	_redraw()


## Fixed rows are selectable too, so what they are bound to can be read; they just
## can't be changed.
func _selectable(i: int) -> bool:
	return _entries[i].has("id")


func _first_selectable() -> int:
	for i in _entries.size():
		if _selectable(i):
			return i
	return 0


func _selected_id() -> StringName:
	return _entries[_row].get("id", &"")


func _kind() -> int:
	return COLUMNS[_col][0]


func _slot() -> int:
	return COLUMNS[_col][1]
