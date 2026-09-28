extends VBoxContainer
class_name ShipPage

## SHIP (docs/GLOSSARY.md, docs/adr/0014): the dock's page for the ship itself. A line
## drawing of the hull with what is fitted, the ship's STATUS, and below them the rows
## SpacePortDialogue runs (`rows`): FIT for each Component waiting in the Cradle, STOW for
## each one on the hull, BACK. The row under the cursor previews itself: a FIT blinks its
## Component in its place, a STOW dims it, and STATUS shows what would change.

## Handling is shown in eighths, never as a number.
const HANDLING_SEGMENTS := 8
const STAT_LABEL_WIDTH := 110.0

var rows: VBoxContainer
var schematic: ShipSchematic

var _hull_value: RichTextLabel
var _fuel_value: RichTextLabel
var _hold_row: Control
var _hold_value: RichTextLabel
var _handling: Control
var _handling_now := HANDLING_SEGMENTS
var _handling_then := HANDLING_SEGMENTS

func _init() -> void:
	add_theme_constant_override("separation", 8)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	schematic = ShipSchematic.new()
	add_child(schematic)
	add_child(_header("S T A T U S"))
	_hull_value = _stat_row("HULL")
	_fuel_value = _stat_row("FUEL")
	_hold_value = _stat_row("HOLD")
	_hold_row = _hold_value.get_parent()
	var handling_row := _row("HANDLING")
	_handling = Control.new()
	_handling.custom_minimum_size = Vector2(0, 12)
	_handling.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_handling.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_handling.draw.connect(_draw_handling)
	handling_row.add_child(_handling)
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	add_child(gap)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	add_child(rows)

## Show `ship` with the Components `now` on it, previewing `then` (what it would wear after
## the row under the cursor): `ghost` is the one it would fit, `leaving` the one it would
## lose. With nothing previewed, `then` is `now`.
func show_ship(ship: Ship, now: PackedStringArray, then: PackedStringArray, ghost := "", leaving := "") -> void:
	schematic.show_ship(ship, now, ghost, leaving)
	if not is_instance_valid(ship):
		return
	_hull_value.text = "%d" % roundi(ship.max_hull)
	_fuel_value.text = "%d" % roundi(ship.drive.max_fuel)
	var hold_now := Components.hold(Array(now))
	var hold_then := Components.hold(Array(then))
	# HOLD shows only once there is one, like the HUD's readout
	_hold_row.visible = hold_now > 0.0 or hold_then > 0.0
	_hold_value.text = _change(hold_now, hold_then)
	_handling_now = _segments(ship.handling(now))
	_handling_then = _segments(ship.handling(then))
	_handling.queue_redraw()

## `then`'s segments of handling: never none, and eight for a bare hull.
static func _segments(handling: float) -> int:
	return clampi(roundi(handling * HANDLING_SEGMENTS), 1, HANDLING_SEGMENTS)

## "50", or "- -> 50" in green when a preview raises it, in rust when it lowers it.
func _change(now: float, then: float) -> String:
	var shown := func(v: float) -> String: return "%d" % roundi(v) if v > 0.0 else "-"
	if is_equal_approx(now, then):
		return shown.call(now)
	var to := Colors.SUCCESS if then > now else Colors.DANGER
	return "[color=#%s]%s ->[/color] [color=#%s]%s[/color]" % [
		Colors.hex(Colors.TEXT_MUTED), shown.call(now), Colors.hex(to), shown.call(then)]

## Eight segments: kept ones mustard, ones a preview would lose rust, ones it would gain
## sage, the rest dim.
func _draw_handling() -> void:
	var gap := 2.0
	var w := (_handling.size.x - gap * (HANDLING_SEGMENTS - 1)) / HANDLING_SEGMENTS
	for i in HANDLING_SEGMENTS:
		var color := Colors.PRIMARY_DIM
		if i < mini(_handling_now, _handling_then):
			color = Colors.PRIMARY
		elif i < _handling_now:
			color = Colors.DANGER
		elif i < _handling_then:
			color = Colors.SUCCESS
		_handling.draw_rect(Rect2(i * (w + gap), 0, w, _handling.size.y), color)

func _header(text: String) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", Colors.PRIMARY)
	label.text = text
	return label

func _row(title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := Label.new()
	name_label.text = title
	name_label.custom_minimum_size.x = STAT_LABEL_WIDTH
	name_label.add_theme_color_override("font_color", Colors.PRIMARY_DIM)
	row.add_child(name_label)
	add_child(row)
	return row

func _stat_row(title: String) -> RichTextLabel:
	var row := _row(title)
	var value := RichTextLabel.new()
	value.bbcode_enabled = true
	value.fit_content = true
	value.scroll_active = false
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.add_theme_color_override("default_color", Colors.TEXT_SECONDARY)
	row.add_child(value)
	return value
