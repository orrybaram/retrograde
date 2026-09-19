class_name RecordsTab
extends LogTab

## The Log's second tab: one Record per Body the player has Visited and per Automaton
## they have met, each section a list on the left and the selected Record opened out on
## the right. One cursor runs through both sections, top to bottom.
##
## The Log lists only what the player reached — no row for anywhere unvisited, and
## never `? ? ?` (docs/adr/0003). The Bodies section reads GameState.visited_planets
## and never the `planets` group: a row per Body in the scene would tell the player how
## many there are to find, which is the spoiler docs/adr/0002 protects.
##
## A Record about an Automaton is the player's own note on it, not the Automaton being
## present: nothing speaks from inside the Log (CONTEXT.md).

## Shown while the player holds no Records. It says what earns one; it never hints at
## how many there are to find.
const EMPTY_STATE := [
	"NOTHING LOGGED YET.",
	"",
	"A BODY EARNS ITS RECORD WHEN YOU FLY INTO ITS ORBIT.",
	"AN AUTOMATON EARNS ONE WHEN YOU MEET IT.",
]

## What a Record reads before the Planetary Scanner has surveyed the Body. Visiting
## earns the Record; scanning fills it in — a scanned row carries the survey in one
## line (PlanetScan.summary_line) instead.
const NO_SURVEY := "NO SURVEY"
## The keys this tab owns, laid before the shell's in the bottom border.
const CURSOR_KEYS := "[UP/DOWN] SELECT"
const TEXT_SIZE := TerminalWindow.TEXT_SIZE
## How wide the open Record is. A Note is written in lines, not reflowed prose, so
## the pane has to be wide enough to hold an authored line without breaking it.
const DETAIL_WIDTH := 440.0

var gs: GameState = null

var _empty: VBoxContainer
# --- Bodies ------------------------------------------------------------------
var _bodies: VBoxContainer
var _body_rows: VBoxContainer
var _body_detail: VBoxContainer
## The Visited Bodies by Planet.save_key(), in the order the player reached them.
var _visited: PackedStringArray = PackedStringArray()
# --- Automatons --------------------------------------------------------------
var _automatons: VBoxContainer
var _automaton_rows: VBoxContainer
var _automaton_detail: VBoxContainer
## The Automatons the player has met, in Automatons.ALL order.
var _met: Array[NPCData] = []
## One cursor over every row in the tab, Bodies first and Automatons after, so UP /
## DOWN carry from one section into the next with no second level of navigation.
var _cursor := 0


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 10)
	_build()


func tab_title() -> String:
	return TerminalWindow.spaced("RECORDS")


## The cursor keys only exist once there is something to move through; a player who has
## stayed home is offered the shell's keys alone.
func hint() -> String:
	if _row_count() == 0:
		return SHELL_KEYS
	return "%s   %s" % [CURSOR_KEYS, SHELL_KEYS]


func _build() -> void:
	add_child(TerminalWindow.header("R E C O R D S"))
	_empty = VBoxContainer.new()
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty.add_theme_constant_override("separation", 4)
	for line in EMPTY_STATE:
		_empty.add_child(TerminalWindow.label(line, TerminalWindow.TEXT_SIZE, Colors.PRIMARY_DIM))
	add_child(_empty)
	_bodies = _build_bodies()
	add_child(_bodies)
	_automatons = _build_automatons()
	add_child(_automatons)
	add_child(TerminalWindow.filler())


## The Bodies section: the Visited list on the left, the selected Record on the right.
func _build_bodies() -> VBoxContainer:
	var section := VBoxContainer.new()
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_theme_constant_override("separation", 8)
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_child(gap)
	section.add_child(TerminalWindow.header("B O D I E S"))

	var columns := HBoxContainer.new()
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_theme_constant_override("separation", 20)
	_body_rows = VBoxContainer.new()
	_body_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_rows.add_theme_constant_override("separation", 4)
	columns.add_child(_body_rows)
	columns.add_child(TerminalWindow.rule(true))
	_body_detail = VBoxContainer.new()
	_body_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_detail.custom_minimum_size.x = DETAIL_WIDTH
	_body_detail.add_theme_constant_override("separation", 4)
	columns.add_child(_body_detail)
	section.add_child(columns)
	return section


## The Automatons section: the ones met on the left, the selected Record on the right.
func _build_automatons() -> VBoxContainer:
	var section := VBoxContainer.new()
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_theme_constant_override("separation", 8)
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_child(gap)
	section.add_child(TerminalWindow.header("A U T O M A T O N S"))

	var columns := HBoxContainer.new()
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_theme_constant_override("separation", 20)
	_automaton_rows = VBoxContainer.new()
	_automaton_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_automaton_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_automaton_rows.add_theme_constant_override("separation", 4)
	columns.add_child(_automaton_rows)
	columns.add_child(TerminalWindow.rule(true))
	_automaton_detail = VBoxContainer.new()
	_automaton_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_automaton_detail.custom_minimum_size.x = DETAIL_WIDTH
	_automaton_detail.add_theme_constant_override("separation", 4)
	columns.add_child(_automaton_detail)
	section.add_child(columns)
	return section


# --- Content -----------------------------------------------------------------

## Planet.save_key() of the Record the cursor is on, or "" when it holds none.
## For tests and playtests.
func selected_key() -> String:
	return _visited[_cursor] if _cursor < _visited.size() else ""

func refresh() -> void:
	gs = get_tree().get_first_node_in_group("game_state") as GameState
	_visited = PackedStringArray(gs.visited_planets.keys()) if gs else PackedStringArray()
	_met = Automatons.met(gs)
	_cursor = clampi(_cursor, 0, maxi(_row_count() - 1, 0))
	# An empty list is correct output for a player who has stayed home and met nobody.
	_empty.visible = _row_count() == 0
	_bodies.visible = not _visited.is_empty()
	_automatons.visible = not _met.is_empty()
	_draw_rows()
	_draw_detail()
	_draw_automaton_rows()
	_draw_automaton_detail()


## Every row the cursor moves through, across both sections.
func _row_count() -> int:
	return _visited.size() + _met.size()


## Where the cursor sits in the Automatons section; negative while it is on a Body.
func _automaton_index() -> int:
	return _cursor - _visited.size()


func _draw_rows() -> void:
	_clear(_body_rows)
	for i in _visited.size():
		var key := _visited[i]
		var selected := i == _cursor
		var body := Planet.find_by_key(get_tree(), key)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		row.add_child(TerminalWindow.label(">" if selected else " ", TEXT_SIZE, Colors.PRIMARY))
		row.add_child(TerminalWindow.label(designation(key, body), TEXT_SIZE,
				Colors.PRIMARY if selected else Colors.TEXT))
		row.add_child(TerminalWindow.spacer())
		var surveyed := body != null and body.is_scanned()
		row.add_child(TerminalWindow.label(
				PlanetScan.summary_line(body) if surveyed else NO_SURVEY, TEXT_SIZE,
				Colors.PRIMARY if surveyed else Colors.PRIMARY_DIM))
		_body_rows.add_child(row)



## The selected Record: the designation, what a moon orbits, and either the survey the
## scanner wrote or the fact that nothing has surveyed this Body yet. A survey is the
## same rows the ScanPanel types out as the scan lands — one survey format in the game,
## and the sun reads through it honestly rather than being special-cased.
func _draw_detail() -> void:
	_clear(_body_detail)
	if _visited.is_empty() or _automaton_index() >= 0:
		return
	var key := _visited[_cursor]
	var body := Planet.find_by_key(get_tree(), key)
	var lines: PackedStringArray
	if body != null and body.is_scanned():
		lines = PlanetScan.readout_lines(body)
	else:
		lines = PlanetScan.identity_lines(designation(key, body), orbits(body))
		lines.append("")
		lines.append(NO_SURVEY)
	for line in lines:
		var color := Colors.PRIMARY_DIM if line == NO_SURVEY else Colors.PRIMARY
		_body_detail.add_child(TerminalWindow.label(line, TEXT_SIZE, color))


## What the Body is called. A loaded Body knows its own name; a key held over from one
## that is not in the scene still reads as its own last path segment.
static func designation(key: String, body: Planet) -> String:
	if body != null:
		return body.planet_name.to_upper()
	var parts := key.split("/")
	return parts[parts.size() - 1].to_upper()


## What `body` orbits, for a moon; "" for anything else, including a planet round the
## sun — the survey readout names a parent only for a moon.
static func orbits(body: Planet) -> String:
	if body != null and body.is_moon():
		return body.parent_planet.planet_name.to_upper()
	return ""


# --- Input -------------------------------------------------------------------

func handle_key(keycode: int) -> bool:
	if _row_count() == 0:
		return false
	match keycode:
		KEY_UP:
			_move_cursor(-1)
			return true
		KEY_DOWN:
			_move_cursor(1)
			return true
	return false


func _move_cursor(direction: int) -> void:
	var n := _row_count()
	_cursor = (_cursor + direction + n) % n
	_draw_rows()
	_draw_detail()
	_draw_automaton_rows()
	_draw_automaton_detail()


# --- Automatons --------------------------------------------------------------

## One row per Automaton the player has met: designation on the left, the station it is
## found at on the right. Nobody met, no rows and no heading (docs/adr/0003).
func _draw_automaton_rows() -> void:
	_clear(_automaton_rows)
	for i in _met.size():
		var npc := _met[i]
		var selected := i == _automaton_index()
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		row.add_child(TerminalWindow.label(">" if selected else " ", TEXT_SIZE, Colors.PRIMARY))
		row.add_child(TerminalWindow.label(npc.record_key(), TEXT_SIZE,
				Colors.PRIMARY if selected else Colors.TEXT))
		row.add_child(TerminalWindow.spacer())
		row.add_child(TerminalWindow.label(npc.station, TEXT_SIZE, Colors.PRIMARY_DIM))
		_automaton_rows.add_child(row)


## The selected Automaton's Record: who it is, where it is found, what it looks like,
## and the Notes the player has written down so far. A Body's Record is instrument
## output and an Automaton's is Notes, so the two do not share a voice (CONTEXT.md) —
## this one is headed by the designation rather than laid out as a readout.
func _draw_automaton_detail() -> void:
	_clear(_automaton_detail)
	var index := _automaton_index()
	if index < 0 or index >= _met.size():
		return
	var npc := _met[index]
	_automaton_detail.add_child(TerminalWindow.label(npc.record_key(),
			TerminalWindow.HEADER_SIZE, Colors.PRIMARY))
	_automaton_detail.add_child(TerminalWindow.label("STATION   %s" % npc.station,
			TerminalWindow.SMALL_SIZE, Colors.PRIMARY_DIM))
	if npc.ascii_art != "":
		_automaton_detail.add_child(TerminalWindow.label(npc.ascii_art, TEXT_SIZE, Colors.PRIMARY))
	# Notes arrive one Module at a time, so a Record read early is a portrait and the
	# one Note keyed to no Modules online. The rest are absent until their step, with
	# nothing standing in for them (docs/adr/0003).
	for note in npc.notes_at(gs.titan_influence() if gs else 0):
		_automaton_detail.add_child(_note_gap())
		var line := TerminalWindow.label(note, TEXT_SIZE, Colors.TEXT)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = DETAIL_WIDTH
		_automaton_detail.add_child(line)

## The blank line that keeps one Note from running into the portrait or the Note above
## it — each Note is its own scrap of writing, not a paragraph of one.
func _note_gap() -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


## Rows are rebuilt on every cursor move, so they come out of the tree there and then
## rather than waiting on a frame that a redraw may beat.
func _clear(box: Container) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.free()
