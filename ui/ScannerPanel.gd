extends Control
class_name ScannerPanel

## The transit scanner: what is out there, which way, and how far.
##
## One row per encounter, nearest first — the design doc's moment-to-moment decision is
## "detour or stay on course" (docs/DESIGN.md §4.1), and that only works if a knot of
## eight debris chunks reads as one contact rather than eight. EncounterField groups them;
## this just draws the list.
##
## Bearings are relative to the ship's nose, the way the player has to fly: negative is
## to port, positive to starboard, 0 is dead ahead.

## How far the scanner reaches. Matches Minimap.world_range so the list and the minimap
## always agree about what is out there. A scanner upgrade would raise this.
const RANGE := 10000.0
const MAX_ROWS := 5
const REFRESH_INTERVAL := 0.2

const MARGIN := 14.0
const PADDING := 8.0
const HEADER_FONT_SIZE := 9
const ROW_FONT_SIZE := 10
const ROW_SEPARATION := 2

var _panel: PanelContainer
var _rows: VBoxContainer
var _header: Label
var _row_labels: Array[Label] = []
var _ship: Ship = null
var _field: EncounterField = null
var _timer := 0.0

func _ready() -> void:
	name = "ScannerPanel"
	add_to_group("scanner_panel")
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE

	_panel = PanelContainer.new()
	_panel.mouse_filter = MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _frame())
	# Laid out by hand rather than by anchors: the panel is as wide as its widest row,
	# and _place() pins its right edge to the screen's. Anchoring it top-right instead
	# leaves the rows running off the edge as they grow.
	add_child(_panel)

	var margins := MarginContainer.new()
	margins.mouse_filter = MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, int(PADDING))
	_panel.add_child(margins)

	_rows = VBoxContainer.new()
	_rows.mouse_filter = MOUSE_FILTER_IGNORE
	_rows.add_theme_constant_override("separation", ROW_SEPARATION)
	margins.add_child(_rows)

	_header = _make_label(HEADER_FONT_SIZE, Colors.PRIMARY_FADED)
	_header.text = "S C A N"
	for i in MAX_ROWS:
		var row := _make_label(ROW_FONT_SIZE, Colors.PRIMARY)
		row.visible = false
		_row_labels.append(row)

	_panel.visible = false

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = REFRESH_INTERVAL
	_refresh()

func _refresh() -> void:
	if not _gameplay_active():
		_panel.visible = false
		return
	var contacts := _field.contacts_in_range(_ship.global_position, RANGE)
	if contacts.is_empty():
		_panel.visible = false
		return

	for i in MAX_ROWS:
		var row := _row_labels[i]
		if i >= contacts.size():
			row.visible = false
			continue
		var contact := contacts[i]
		var offset := contact.position() - _ship.global_position
		row.visible = true
		row.text = format_row(contact.label, bearing_to(_ship.rotation, offset), offset.length())
	_place()
	_panel.visible = true

## Pin the panel to the top-right corner at whatever width its rows currently need.
## Containers grow on their own but never shrink back, so both are reset first.
func _place() -> void:
	_rows.reset_size()
	_panel.reset_size()
	_panel.position = Vector2(size.x - _panel.size.x - MARGIN, MARGIN)

## True while the scanner has anything to report.
func is_scanning() -> bool:
	return _panel != null and _panel.visible

## The lines currently on air, top (nearest) first.
func rows() -> PackedStringArray:
	var out := PackedStringArray()
	if not is_scanning():
		return out
	for row in _row_labels:
		if row.visible:
			out.append(row.text)
	return out

## Degrees the ship would have to turn to point at `offset`: negative to port, positive
## to starboard, 0 dead ahead.
static func bearing_to(heading: float, offset: Vector2) -> float:
	return rad_to_deg(wrapf(offset.angle() - heading, -PI, PI))

## One scanner line: what it is, which way to turn, how far. Padded so the columns line
## up down the panel.
static func format_row(label: String, bearing_deg: float, distance: float) -> String:
	return "%-9s %+04d° %8s" % [label, roundi(bearing_deg), TrackingSolution.format_distance(distance)]

func _gameplay_active() -> bool:
	if not _ship or not is_instance_valid(_ship):
		_ship = get_tree().get_first_node_in_group("ship") as Ship
	if not _field or not is_instance_valid(_field):
		_field = EncounterField.get_instance(get_tree())
	if not _ship or not _field:
		return false
	var main := get_tree().get_first_node_in_group("main")
	if main and main.current_game_state != main.MainGameState.PLAYING:
		return false
	# Docked or wrecked, the scanner isn't the thing in front of you
	return not _ship.is_destroyed() and not _ship.is_locked_to_planet()

## Bordered terminal frame: mustard outline, no fill of its own beyond the panel dark.
func _frame() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Colors.UI_BACKGROUND
	box.border_color = Colors.UI_BORDER
	box.set_border_width_all(1)
	return box

func _make_label(font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	_rows.add_child(label)
	return label
