class_name RecordsTab
extends LogTab

## The Log's second tab: one Record per Body the player has Visited, per Automaton
## they have met, and per piece of Hardware the ship has read up close (Readout). Both sections list down the left; one detail column on the right
## carries whichever Record the cursor is on, whichever section that is. One cursor runs
## through both sections, top to bottom, and one rule divides the tab full height.
##
## The Log lists only what the player reached — no row for anywhere unvisited, and
## never `? ? ?`. The Bodies section reads the ledger's Progress.VISITED_BODIES
## and never the `planets` group: a row per Body in the scene would tell the player how
## many there are to find, and that is a spoiler.
##
## A Record about an Automaton is the player's own note on it, not the Automaton being
## present: nothing speaks from inside the Log.
##
## A Hardware Record is what the ship read, as the thing stands now; for a kind many things
## share (every piece of scrap), what the kind reads as. Something undecipherable has no
## Record: nothing was learned from it.

## Shown while the player holds no Records. It says what earns one; it never hints at
## how many there are to find.
const EMPTY_STATE := [
	"NOTHING LOGGED YET.",
	"",
	"A BODY EARNS ITS RECORD WHEN YOU FLY INTO ITS ORBIT.",
	"AN AUTOMATON EARNS ONE WHEN YOU MEET IT.",
	"HARDWARE EARNS ONE WHEN YOU COME CLOSE ENOUGH TO READ IT.",
]

## What a Record reads before the Body has been surveyed. The Body itself is known — the
## player flew into its orbit and the row carries its name; it is the survey that is
## missing. A survey (none in play yet; the planetary scan is gone) would fill it in and
## the row carries the survey in one line (PlanetScan.summary_line) instead.
const NO_SURVEY := "UNSURVEYED"
## The keys this tab owns, laid before the shell's in the bottom border.
static func cursor_keys() -> String:
	return "[%s] SELECT" % Controls.nav_label()
const TEXT_SIZE := TerminalWindow.TEXT_SIZE
## Section headings inside the list column. Smaller than TerminalWindow.header(): these
## label a list within a column rather than a panel of the screen.
const HEADING_SIZE := TerminalWindow.SMALL_SIZE
## How far a place's Hardware sits in from the place's name (file_hardware).
const PLACE_INDENT := 12.0
## How wide the open Record is. A Note is written in lines, not reflowed prose, so
## the pane has to be wide enough to hold an authored line without breaking it.
const DETAIL_WIDTH := 440.0
## The list column takes one part of the tab's width, the open Record two.
const LIST_RATIO := 1.0
const DETAIL_RATIO := 2.0

var gs: GameState = null

var _empty: VBoxContainer
## The lists down the left, the rule, and the one detail column on the right.
var _columns: HBoxContainer
var _detail: VBoxContainer
# --- Bodies ------------------------------------------------------------------
var _bodies: VBoxContainer
var _body_rows: VBoxContainer
## The Visited Bodies by Planet.save_key(), in the order the player reached them.
var _visited: PackedStringArray = PackedStringArray()
# --- Automatons --------------------------------------------------------------
var _automatons: VBoxContainer
var _automaton_rows: VBoxContainer
## The Automatons the player has met, in Automatons.ALL order.
var _met: Array[NPCData] = []
# --- Hardware ----------------------------------------------------------------
var _hardware: VBoxContainer
var _hardware_rows: VBoxContainer
## The readouts the ship has read, filed by place (file_hardware).
var _read: Array[Dictionary] = []
## One cursor over every row in the tab, Bodies first, then Automatons, then Hardware, so
## UP / DOWN carry from one section into the next with no second level of navigation.
var _cursor := 0


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 10)
	_build()


func tab_title() -> String:
	return "RECORDS"


## The cursor keys only exist once there is something to move through; a player who has
## stayed home is offered the shell's keys alone.
func hint() -> String:
	if _row_count() == 0:
		return shell_keys()
	return "%s   %s" % [cursor_keys(), shell_keys()]


func _build() -> void:
	# No "R E C O R D S" heading over the whole tab: the notch in the border already
	# says which tab this is, and the headings in here name sections, as the Hold's do.
	_empty = VBoxContainer.new()
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty.add_theme_constant_override("separation", 4)
	for line in EMPTY_STATE:
		_empty.add_child(TerminalWindow.label(line, TerminalWindow.TEXT_SIZE, Colors.PRIMARY_DIM))
	add_child(_empty)

	# Both sections share one detail column, so the rule between them runs the full
	# height of the tab whichever section the cursor is in — there is no second, blank
	# detail pane leaving an orphan stroke behind it.
	_columns = HBoxContainer.new()
	_columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_columns.add_theme_constant_override("separation", 20)

	# The list is a third of the tab and the open Record two thirds: the list carries a
	# name and a one-line summary, the Record carries a survey or a column of Notes.
	var lists := VBoxContainer.new()
	lists.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lists.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lists.size_flags_stretch_ratio = LIST_RATIO
	lists.add_theme_constant_override("separation", 12)
	_bodies = _build_bodies()
	lists.add_child(_bodies)
	_automatons = _build_automatons()
	lists.add_child(_automatons)
	_hardware = _section("H A R D W A R E", func(rows: VBoxContainer) -> void: _hardware_rows = rows)
	lists.add_child(_hardware)
	lists.add_child(TerminalWindow.filler())
	_columns.add_child(lists)

	_columns.add_child(TerminalWindow.rule(true))
	_detail = VBoxContainer.new()
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.size_flags_stretch_ratio = DETAIL_RATIO
	_detail.custom_minimum_size.x = DETAIL_WIDTH
	_detail.add_theme_constant_override("separation", 4)
	_columns.add_child(_detail)
	add_child(_columns)

## The Visited Bodies. Sections stack one straight after the other rather than sharing
## the height between them, so a short list does not leave a gap before the next
## heading; one filler under the last section takes up whatever is left.
func _build_bodies() -> VBoxContainer:
	return _section("B O D I E S", func(rows: VBoxContainer) -> void: _body_rows = rows)

## The Automatons the player has met.
func _build_automatons() -> VBoxContainer:
	return _section("A U T O M A T O N S", func(rows: VBoxContainer) -> void: _automaton_rows = rows)


## One list section: a quiet heading over its rows. The heading is smaller than a Hold
## header — it labels a list inside a column, not a panel — and it never grows to fill.
func _section(title: String, take_rows: Callable) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_theme_constant_override("separation", 6)
	section.add_child(TerminalWindow.label(title, HEADING_SIZE, Colors.PRIMARY_DIM))
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 4)
	section.add_child(rows)
	take_rows.call(rows)
	return section

# --- Content -----------------------------------------------------------------

## Planet.save_key() of the Record the cursor is on, or "" when it holds none.
## For tests and playtests.
func selected_key() -> String:
	return _visited[_cursor] if _cursor < _visited.size() else ""

func refresh() -> void:
	gs = get_tree().get_first_node_in_group("game_state") as GameState
	_visited = gs.progress.list(Progress.VISITED_BODIES) if gs else PackedStringArray()
	_met = Automatons.met(gs)
	_read = file_hardware(read_hardware(get_tree(), gs))
	_cursor = clampi(_cursor, 0, maxi(_row_count() - 1, 0))
	# An empty list is correct output for a player who has stayed home and met nobody.
	_empty.visible = _row_count() == 0
	_columns.visible = _row_count() > 0
	_bodies.visible = not _visited.is_empty()
	_automatons.visible = not _met.is_empty()
	_hardware.visible = not _read.is_empty()
	_redraw()


## Every row the cursor moves through, across both sections.
func _row_count() -> int:
	return _visited.size() + _met.size() + _read.size()


## Where the cursor sits in the Automatons section; negative while it is on a Body.
func _automaton_index() -> int:
	return _cursor - _visited.size()


## Where the cursor sits in the Hardware section; negative above it.
func _hardware_index() -> int:
	return _cursor - _visited.size() - _met.size()


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


## The one detail column, opened out on whichever Record the cursor is on. A Body's
## Record is instrument output and an Automaton's is Notes, so the two do not share a
## voice — but they do share this column, which is what keeps the rule
## beside it running full height instead of stopping at an empty pane.
func _draw_detail() -> void:
	_clear(_detail)
	var index := _automaton_index()
	if _hardware_index() >= 0:
		_draw_hardware_detail(_hardware_index())
	elif index >= 0:
		_draw_automaton_detail(index)
	elif not _visited.is_empty():
		_draw_body_detail(_visited[_cursor])

## The selected Body's Record: the designation, what a moon orbits, and either the
## survey or the fact that nothing has surveyed this Body yet. A survey is
## PlanetScan.readout_lines — one survey format in the game, and the sun reads through it honestly rather than being special-cased.
func _draw_body_detail(key: String) -> void:
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
		_detail.add_child(TerminalWindow.label(line, TEXT_SIZE, color))


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

func handle_action(action: StringName) -> bool:
	if _row_count() == 0:
		return false
	match action:
		&"menu_up":
			_move_cursor(-1)
			return true
		&"menu_down":
			_move_cursor(1)
			return true
	return false


func _move_cursor(direction: int) -> void:
	var n := _row_count()
	_cursor = (_cursor + direction + n) % n
	_redraw()

## Both lists and the one detail column, which always shows the Record under the cursor.
func _redraw() -> void:
	_draw_rows()
	_draw_automaton_rows()
	_draw_hardware_rows()
	_draw_detail()


# --- Automatons --------------------------------------------------------------

## One row per Automaton the player has met: designation on the left, the station it is
## found at on the right. Nobody met, no rows and no heading.
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
## and the Notes the player has written down so far. It is headed by the designation
## rather than laid out as a readout, so it never reads as instrument output.
func _draw_automaton_detail(index: int) -> void:
	if index >= _met.size():
		return
	var npc := _met[index]
	_detail.add_child(TerminalWindow.label(npc.record_key(),
			TerminalWindow.HEADER_SIZE, Colors.PRIMARY))
	_detail.add_child(TerminalWindow.label("STATION   %s" % npc.station,
			TerminalWindow.SMALL_SIZE, Colors.PRIMARY_DIM))
	# Notes arrive one Module at a time, so a Record read early is a portrait and the
	# one Note keyed to no Modules online. The rest are absent until their step, with
	# nothing standing in for them.
	for note in npc.notes_at(gs.titan_influence() if gs else 0):
		_detail.add_child(_note_gap())
		var line := TerminalWindow.label(note, TEXT_SIZE, Colors.TEXT)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = DETAIL_WIDTH
		_detail.add_child(line)

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


# --- Hardware ----------------------------------------------------------------

## A Record for every key the ledger says the ship has read, in the order read:
## {key, heading, title, category, rows}. A key many things share (scrap) shows its
## registered kind (Readout.register_kind); any other shows its thing as it stands now.
## Undecipherable things are left out: nothing was learned from them.
static func read_hardware(tree: SceneTree, state: GameState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if state == null:
		return out
	var by_key := {}
	for node in tree.get_nodes_in_group("readouts"):
		var r := node as Readout
		if r and not r.undecipherable and r.ledger_key() != "":
			by_key[r.ledger_key()] = r
	for at in state.progress.list(Progress.READ_READOUTS):
		var record := Readout.kind(at)
		if not record.is_empty():
			out.append(record.merged({"key": at}))
		elif by_key.has(at):
			var r: Readout = by_key[at]
			out.append({"key": at, "heading": r.heading, "title": r.title, "category": r.category,
					"rows": r.rows_now()})
	return out


## `read` filed by place (Readout.category): each place's things together, the places in
## the order their first thing was read, and read order kept within a place. The cursor runs
## through them in this order, so it moves down the list as drawn.
static func file_hardware(read: Array[Dictionary]) -> Array[Dictionary]:
	var places: PackedStringArray = []
	var by_place := {}
	for r in read:
		if not by_place.has(r.category):
			places.append(r.category)
			by_place[r.category] = []
		by_place[r.category].append(r)
	var out: Array[Dictionary] = []
	for place in places:
		out.append_array(by_place[place])
	return out


## One row per piece of Hardware read: what it is on the left, its first row's value (its
## state) on the right. A place's things sit indented under its name; a thing filed under no
## place sits at the section's own margin.
func _draw_hardware_rows() -> void:
	_clear(_hardware_rows)
	var place := ""
	for i in _read.size():
		var r := _read[i]
		if r.category != place:
			place = r.category
			if place != "":
				_hardware_rows.add_child(_place_heading(place))
		var selected := i == _hardware_index()
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		if place != "":
			row.add_child(_indent())
		row.add_child(TerminalWindow.label(">" if selected else " ", TEXT_SIZE, Colors.PRIMARY))
		row.add_child(TerminalWindow.label(r.title if r.title != "" else r.heading, TEXT_SIZE,
				Colors.PRIMARY if selected else Colors.TEXT))
		row.add_child(TerminalWindow.spacer())
		var rows: Array = r.rows
		row.add_child(TerminalWindow.label(rows[0].value if not rows.is_empty() else r.heading,
				TEXT_SIZE, Colors.PRIMARY_DIM))
		_hardware_rows.add_child(row)


## A place's name over its things in the Hardware list: quieter than a section heading, and
## not a row, so the cursor passes over it.
func _place_heading(place: String) -> Control:
	return TerminalWindow.label(place, HEADING_SIZE, Colors.PRIMARY_DIM)


func _indent() -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.x = PLACE_INDENT
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


## The selected Hardware's Record: what it is, then its rows as the thing stands now.
func _draw_hardware_detail(index: int) -> void:
	if index >= _read.size():
		return
	var r := _read[index]
	_detail.add_child(TerminalWindow.label(r.title if r.title != "" else r.heading,
			TerminalWindow.HEADER_SIZE, Colors.PRIMARY))
	# What it is and where: `MOUNT` under a title, `SR-7 / MOUNT` once it has a place.
	var subtitle: PackedStringArray = []
	if r.category != "":
		subtitle.append(r.category)
	if r.title != "":
		subtitle.append(r.heading)
	if not subtitle.is_empty():
		_detail.add_child(TerminalWindow.label(" / ".join(subtitle), TerminalWindow.SMALL_SIZE,
				Colors.PRIMARY_DIM))
	_detail.add_child(_note_gap())
	for row: ReadoutRow in r.rows:
		_detail.add_child(TerminalWindow.label(hardware_line(row), TEXT_SIZE, Colors.TEXT))


## `STATE ........ EMPTY`, in the contact log's columns.
static func hardware_line(row: ReadoutRow) -> String:
	var line := ""
	for seg in BootChecklist.field(row.label, row.value, Colors.TEXT):
		line += seg[0]
	return line
