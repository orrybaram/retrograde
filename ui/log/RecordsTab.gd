class_name RecordsTab
extends LogTab

## The Log's second tab: one Record per Body the player has Visited and per Automaton
## they have met. This slice renders the heading and the empty state only; the Records
## themselves land in a later slice.
##
## The Log lists only what the player reached — no row for anywhere unvisited, and
## never `? ? ?` (docs/adr/0003).

## Shown while the player holds no Records. It says what earns one; it never hints at
## how many there are to find.
const EMPTY_STATE := [
	"NOTHING LOGGED YET.",
	"",
	"A BODY EARNS ITS RECORD WHEN YOU FLY INTO ITS ORBIT.",
	"AN AUTOMATON EARNS ONE WHEN YOU MEET IT.",
]

var _empty: VBoxContainer


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 10)
	_build()


func tab_title() -> String:
	return TerminalWindow.spaced("RECORDS")


func _build() -> void:
	add_child(TerminalWindow.header("R E C O R D S"))
	_empty = VBoxContainer.new()
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty.add_theme_constant_override("separation", 4)
	for line in EMPTY_STATE:
		_empty.add_child(TerminalWindow.label(line, TerminalWindow.TEXT_SIZE, Colors.PRIMARY_DIM))
	add_child(_empty)
	add_child(TerminalWindow.filler())
