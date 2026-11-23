class_name ShipLogTab
extends LogTab

## The Log's first tab: the ship's log (ShipLog), newest first, one line an entry -
## a status dot, the mission time, who wrote it, and a field in the diagnostic's grammar:
##
##   ●  T+01:40  SONR  SOLAR ARRAY ............ LOCATED   NEW
##
## The dot alone carries the status (INFO grey, WARN mustard, ERR red); the rest of the line
## is one ink. Entries written since the Log was last open carry NEW; closing the tab marks
## them seen. Only the newest MAX_ROWS are listed.

const TEXT_SIZE := TerminalWindow.TEXT_SIZE
const SMALL_SIZE := TerminalWindow.SMALL_SIZE
const MAX_ROWS := 24
const DOT := 6.0
const TIME_WIDTH := 92.0
const SOURCE_WIDTH := 52.0
const NEW_TAG := "NEW"
const EMPTY := "NO ENTRIES"

var gs: GameState = null
var _rows: VBoxContainer


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows = VBoxContainer.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_theme_constant_override("separation", 6)
	add_child(_rows)


func tab_title() -> String:
	return "LOG"


func refresh() -> void:
	gs = get_tree().get_first_node_in_group("game_state") as GameState
	for child in _rows.get_children():
		child.free()
	var log := gs.ship_log if gs else null
	if log == null or log.entries.is_empty():
		_rows.add_child(TerminalWindow.label(EMPTY, TEXT_SIZE, Colors.PRIMARY_DIM))
		return
	var i := log.entries.size() - 1
	while i >= 0 and _rows.get_child_count() < MAX_ROWS:
		_rows.add_child(_row(log.entries[i], log.is_new(i)))
		i -= 1


func on_hidden() -> void:
	if gs:
		gs.ship_log.mark_seen()


## The text of every listed line, newest first, as the player reads it (for tests).
func lines() -> PackedStringArray:
	var out := PackedStringArray()
	for row in _rows.get_children():
		var parts := PackedStringArray()
		for child in row.get_children():
			if child is Label:
				parts.append((child as Label).text)
		out.append(" ".join(parts).strip_edges())
	return out


static func line_text(entry: Dictionary) -> String:
	var runs := BootChecklist.field(entry["name"], entry["value"], Colors.TEXT)
	return runs[0][0] + runs[1][0] + runs[2][0]


func _row(entry: Dictionary, fresh: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	var dot_box := CenterContainer.new()
	dot_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(DOT, DOT)
	dot.color = ShipLog.status_color(entry["status"])
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot_box.add_child(dot)
	row.add_child(dot_box)
	var time := TerminalWindow.label(ShipLog.stamp(entry["at"]), SMALL_SIZE, Colors.PRIMARY_DIM)
	time.custom_minimum_size.x = TIME_WIDTH
	row.add_child(time)
	var source := TerminalWindow.label(entry["source"], SMALL_SIZE, Colors.PRIMARY_DIM)
	source.custom_minimum_size.x = SOURCE_WIDTH
	row.add_child(source)
	row.add_child(TerminalWindow.label(line_text(entry), TEXT_SIZE, Colors.TEXT if fresh else Colors.TEXT_SECONDARY))
	if fresh:
		row.add_child(TerminalWindow.label(NEW_TAG, SMALL_SIZE, Colors.PRIMARY))
	return row
