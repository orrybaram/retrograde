extends Control
class_name LoadingScreen

## Boot terminal shown while the solar system generates: a power-on self test that
## works down a fixed checklist, one row per check, with a bar counting them off.
##
## Every row is on screen from the first frame - pending ones ghosted, the running one
## bright with dots writing out behind a cursor, finished ones dimmed and stamped
## [ OK ] - so the panel holds still and can be read rather than scrolling past
## (docs/DESIGN.md "Minute 0-1"). Scanlines and a slow roll band sell the CRT.

const TITLE := "/ S Y S T E M   B O O T /"
const SUBTITLE := "P O W E R - O N   S E L F   T E S T"
const FOOTER := "DO NOT POWER DOWN"
const READY := "> READY"

const TEXT_SIZE := 14
const SMALL_SIZE := 10
## Checks are padded out with dots to this column, then stamped, so every row is the
## same width and the bar below lines up with them.
const DOT_COLUMN := 44
const STAMP_OK := "[ OK ]"
const STAMP_WIDTH := 6
const GUTTER := " "  # breathing room between the dots and the stamp
const ROW_WIDTH := DOT_COLUMN + 1 + STAMP_WIDTH
## Bar cells, so "[cells] 100%" comes out exactly as wide as a checklist row.
const METER_CELLS := ROW_WIDTH - 7
const CURSOR := "█"
## Ink strengths for rows that aren't at full brightness. Colors.hex() drops alpha, so
## these are mixed against the panel instead of faded with it.
const PENDING_INK := 0.20
const DOT_INK := 0.55
const CURSOR_HZ := 3.0
const PANEL_MARGIN := 26
const TITLE_INSET := 22.0  # how far the title sits in from the frame's right corner

## Generation usually finishes long before the checklist has run. The boot sequence is
## meant to be read, so the screen stays up at least this long instead of flashing past.
const MIN_VISIBLE := 3.0

## The checklist runs a little shorter than MIN_VISIBLE on purpose, so the finished
## board and its READY blink get a beat on screen before the screen hands over.
@export var duration: float = 2.4

var _boot_messages: Array[String] = [
	"Initializing navigation systems",
	"Loading stellar database",
	"Calibrating sensors",
	"Establishing communication protocols",
	"Scanning for celestial bodies",
	# Sits between two mundane lines on purpose: nobody reads it the first time
	# (docs/DESIGN.md "The First 10 Minutes").
	"Synchronizing clone manifest",
	"Generating orbital calculations",
	"Finalizing generation",
]

var terminal_label: RichTextLabel = null  # the checklist rows
var _panel: PanelContainer = null
var _title: Label = null
var _meter: RichTextLabel = null
var _ready_label: RichTextLabel = null
var _scanlines: Control = null
var _shown_at := 0.0
var _elapsed := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # always process so it works when paused
	_build()
	_lock_columns()
	visible = false

func show_loading() -> void:
	_shown_at = Time.get_ticks_msec() / 1000.0
	_elapsed = 0.0
	visible = true
	_render()
	_place_title()

## Waits out the rest of MIN_VISIBLE first, so a fast generation still gets read.
## `hold` is false under the playtest driver, which shouldn't sit through it.
func hide_loading(hold: bool = true) -> void:
	var elapsed := Time.get_ticks_msec() / 1000.0 - _shown_at
	if hold and elapsed < MIN_VISIBLE:
		await get_tree().create_timer(MIN_VISIBLE - elapsed, true, false, true).timeout
	visible = false

func _process(_delta: float) -> void:
	if not visible:
		return
	_elapsed = Time.get_ticks_msec() / 1000.0 - _shown_at
	_render()
	_place_title()
	_scanlines.queue_redraw()

# --- Layout ------------------------------------------------------------------

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var backdrop := ColorRect.new()
	backdrop.color = Colors.SPACE_BG
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# The frame sizes itself around the checklist, so the centre container can place it.
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", TerminalWindow.box(
		Colors.UI_BACKGROUND_SOLID, Colors.UI_BORDER, 2))
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, PANEL_MARGIN)
	_panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 10)
	margin.add_child(rows)

	rows.add_child(TerminalWindow.label(SUBTITLE, SMALL_SIZE, Colors.PRIMARY_DIM))
	rows.add_child(TerminalWindow.rule())

	terminal_label = _mono_text(TEXT_SIZE)
	terminal_label.add_theme_constant_override("line_separation", 4)
	rows.add_child(terminal_label)

	rows.add_child(TerminalWindow.rule())

	_meter = _mono_text(TEXT_SIZE)
	rows.add_child(_meter)

	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(foot)
	_ready_label = _mono_text(SMALL_SIZE)
	foot.add_child(_ready_label)
	foot.add_child(TerminalWindow.spacer())
	foot.add_child(TerminalWindow.label(FOOTER, SMALL_SIZE, Colors.PRIMARY_DIM))

	# Notched into the top border, like every other terminal panel. It rides along with
	# the frame in _place_title() rather than anchoring, since the frame is auto-sized.
	_title = TerminalWindow.label(TITLE, SMALL_SIZE, Colors.PRIMARY)
	var tab := StyleBoxFlat.new()
	tab.bg_color = Colors.UI_BACKGROUND_SOLID
	tab.content_margin_left = 8
	tab.content_margin_right = 8
	_title.add_theme_stylebox_override("normal", tab)
	add_child(_title)

	_scanlines = Control.new()
	_scanlines.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scanlines.draw.connect(_draw_scanlines)
	add_child(_scanlines)

## Hold the checklist and the bar at the width of a full row. The frame sizes itself
## around them and the container centres it, so text that grew as it typed would walk
## the whole panel across the screen.
func _lock_columns() -> void:
	var font := terminal_label.get_theme_font("normal_font")
	if font == null:
		return
	# A full row plus the cursor cell every row reserves.
	var width := font.get_string_size(
		"0".repeat(ROW_WIDTH) + CURSOR, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
	terminal_label.custom_minimum_size.x = width
	_meter.custom_minimum_size.x = width

## Sit the title in the top border of the frame, right-hand side.
func _place_title() -> void:
	_title.position = _panel.position + Vector2(
		_panel.size.x - _title.size.x - TITLE_INSET, -_title.size.y / 2.0)

func _mono_text(font_size: int) -> RichTextLabel:
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_size_override("normal_font_size", font_size)
	text.add_theme_color_override("default_color", Colors.PRIMARY)
	return text

# --- The checklist -----------------------------------------------------------

func _render() -> void:
	var steps := _boot_messages.size()
	var step_time := duration / float(steps)
	var running := int(_elapsed / step_time)  # index of the check being run
	var sub := fmod(_elapsed, step_time) / step_time
	var lines := PackedStringArray()
	for i in steps:
		if i < running:
			lines.append(_done_row(_boot_messages[i]))
		elif i == running:
			lines.append(_running_row(_boot_messages[i], sub))
		else:
			lines.append(_pending_row(_boot_messages[i]))
	terminal_label.text = "\n".join(lines)

	var progress := clampf(_elapsed / duration, 0.0, 1.0)
	_meter.text = _meter_text(progress)
	_stamp_ready(progress >= 1.0)

## The board is done: it says so, with the cursor left blinking after it. Like every
## other blink here it's painted out rather than removed, so no row ever changes height.
func _stamp_ready(done: bool) -> void:
	var ink := Colors.SUCCESS if done else Colors.UI_BACKGROUND_SOLID
	_ready_label.text = _tint(READY + " ", ink) + _tint(
		CURSOR, Colors.SUCCESS if done and _blink() else Colors.UI_BACKGROUND_SOLID)

## A check with its dots run out to the stamp column.
static func dotted(message: String) -> String:
	return message.to_upper().rpad(DOT_COLUMN, ".")

## A full row: the dotted check plus its stamp, the same width whatever the stamp says.
static func row_text(message: String, stamp: String) -> String:
	return dotted(message) + GUTTER + stamp.rpad(STAMP_WIDTH)

func _done_row(message: String) -> String:
	return "%s%s%s" % [
		_tint(dotted(message) + GUTTER, Colors.PRIMARY_DIM),
		_tint(STAMP_OK, Colors.SUCCESS),
		_cursor(false),
	]

## Dots write out behind the cursor as the check runs, like the line is being typed.
func _running_row(message: String, sub: float) -> String:
	var head := message.to_upper()
	var room := maxi(DOT_COLUMN - head.length(), 0)
	var dots := clampi(int(sub * room), 0, room)
	return "%s%s%s" % [
		_tint(head, Colors.PRIMARY),
		_tint(".".repeat(dots), _ink(DOT_INK)),
		_cursor(_blink()),
	]

func _pending_row(message: String) -> String:
	return _tint(dotted(message), _ink(PENDING_INK)) + _cursor(false)

## The cursor, lit or painted out. Every row carries one: the block glyph is taller
## than the rest of the font, so a row without it would sit 2px shorter and bounce the
## auto-sized frame each time the cursor moved on.
func _cursor(lit: bool) -> String:
	return _tint(CURSOR, Colors.PRIMARY if lit else Colors.UI_BACKGROUND_SOLID)

## "[####----------]  38%", the same width as the rows above it.
static func meter_text(progress: float) -> String:
	var filled := _filled_cells(progress)
	return "[%s%s]%4d%%" % [
		"#".repeat(filled), "-".repeat(METER_CELLS - filled), int(progress * 100.0)]

func _meter_text(progress: float) -> String:
	var filled := _filled_cells(progress)
	return "%s%s%s%s" % [
		_tint("[", Colors.PRIMARY_DIM),
		_tint("#".repeat(filled), Colors.PRIMARY),
		_tint("-".repeat(METER_CELLS - filled) + "]", Colors.PRIMARY_DIM),
		_tint("%4d%%" % int(progress * 100.0), Colors.PRIMARY),
	]

static func _filled_cells(progress: float) -> int:
	return clampi(roundi(clampf(progress, 0.0, 1.0) * METER_CELLS), 0, METER_CELLS)

func _blink() -> bool:
	return fmod(_elapsed * CURSOR_HZ, 1.0) < 0.6

static func _tint(text: String, color: Color) -> String:
	return "[color=#%s]%s[/color]" % [Colors.hex(color), text]

## Mustard `mix` of the way up from the panel background: a solid dim, not a faded one.
static func _ink(mix: float) -> Color:
	return Colors.UI_BACKGROUND_SOLID.lerp(Colors.PRIMARY, mix)

# --- CRT dressing ------------------------------------------------------------

## One-pixel scanlines over the whole screen, plus a soft band rolling down it.
func _draw_scanlines() -> void:
	var view := _scanlines.size
	var line := Color(Colors.PRIMARY, 0.05)
	for y in range(0, int(view.y), 3):
		_scanlines.draw_line(Vector2(0, y), Vector2(view.x, y), line, 1.0)
	var band_height := 90.0
	var roll := fmod(_elapsed * 140.0, view.y + band_height) - band_height
	_scanlines.draw_rect(Rect2(0, roll, view.x, band_height), Color(Colors.PRIMARY, 0.012))
