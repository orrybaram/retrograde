extends Control
class_name DevPanel

## Developer state editor: put the game in the state a change needs to be seen in,
## without flying there first. Debug builds only — in an export template `_ready`
## drops the node and nothing else in the game refers to it.
##
## F1 (or `) opens it during play and pauses the tree. Sections run down the left,
## rows down the right:
##   TAB / SHIFT+TAB   next / previous section
##   UP / DOWN         pick a row
##   LEFT / RIGHT      nudge a value
##   ENTER             run the row (on a value row: jump it to the top)
##   ESC               close
##
## Warps unpause before they move the ship, so the physics server takes the new
## transform on the next step instead of holding a frozen one.
##
## Built in code from TerminalWindow; the node in Main.tscn is just the root.

signal closed

const WINDOW_SIZE := Vector2(820, 460)
const TEXT_SIZE := TerminalWindow.TEXT_SIZE
const SMALL_SIZE := TerminalWindow.SMALL_SIZE
const ROW_HEIGHT := 22.0
const SECTION_WIDTH := 140.0
const VALUE_WIDTH := 150.0
const PIPS_WIDTH := 44.0

## LEFT/RIGHT on a gauge moves it this fraction of its maximum.
const GAUGE_STEP := 0.1
## LEFT/RIGHT on the credits row.
const CREDIT_STEP := 1000
## ENTER on the credits row.
const CREDIT_JUMP := 25000
## LEFT/RIGHT on a gravity row multiplies or divides by this. Gravity runs from a tenth of
## a G to ten G, so it steps by ratio - a fixed nudge would be lost at one end and wild at
## the other.
const GRAVITY_STEP := 1.25
## How far a gravity row can be pushed either way, so a slip can always be walked back.
const GRAVITY_LIMIT := Vector2(0.01, 100.0)
## Upgrade tracks in display order: path, label, top tier.
const UPGRADE_TRACKS := [
	["hull", "HULL PLATING", 3],
	["fuel_tank", "FUEL TANK", 3],
	["cargo", "CARGO HOLD", 3],
	["planet_scanner", "PLANET SCANNER", 1],
]
## How far off a planet's centre an orbit warp parks, as a multiple of its scan radius.
const ORBIT_DISTANCE := 1.0
## Warping to the Void parks this far inside its edge, so the clock is already running.
const VOID_OVERSHOOT := 2_000.0

var gs: GameState = null

var _sections: Array[Dictionary] = []
var _section_index := 0
var _rows: Array[Dictionary] = []
var _selected := 0

var _frame: TerminalWindow
var _section_box: VBoxContainer
var _section_title: Label
var _row_box: VBoxContainer
var _scroll: ScrollContainer
var _note: Label
var _row_nodes: Array[Control] = []


func _ready() -> void:
	visible = false
	if not OS.is_debug_build():
		queue_free()
		return
	add_to_group("dev_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	gs = get_tree().get_first_node_in_group("game_state") as GameState
	_build_ui()
	_build_sections()


# --- Layout ------------------------------------------------------------------

func _build_ui() -> void:
	_frame = TerminalWindow.new(
		WINDOW_SIZE,
		TerminalWindow.spaced_title("DEV"),
		"[TAB] SECTION   [<>] ADJUST   [ENTER] APPLY   [ESC] CLOSE"
	)
	add_child(_frame)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	_frame.body.add_child(row)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = SECTION_WIDTH
	left.add_theme_constant_override("separation", 10)
	left.add_child(TerminalWindow.header("S E C T I O N"))
	_section_box = VBoxContainer.new()
	_section_box.add_theme_constant_override("separation", 2)
	left.add_child(_section_box)
	left.add_child(TerminalWindow.filler())
	row.add_child(left)
	row.add_child(TerminalWindow.rule(true))

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	_section_title = TerminalWindow.header("")
	right.add_child(_section_title)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row_box = VBoxContainer.new()
	_row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row_box.add_theme_constant_override("separation", 2)
	_scroll.add_child(_row_box)
	right.add_child(_scroll)

	right.add_child(TerminalWindow.rule())
	_note = TerminalWindow.label("", SMALL_SIZE, Colors.PRIMARY_DIM)
	_note.custom_minimum_size.y = 30
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_note)
	row.add_child(right)


## One row: `> LABEL ............ value`, highlighted when selected.
func _make_row(row: Dictionary, selected: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = ROW_HEIGHT
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := TerminalWindow.box(Colors.PRIMARY_GHOST if selected else Color.TRANSPARENT, Colors.PRIMARY_DIM, 0)
	if selected:
		bg.border_width_left = 2
		bg.border_color = Colors.PRIMARY
	bg.content_margin_left = 8
	bg.content_margin_right = 8
	panel.add_theme_stylebox_override("panel", bg)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	panel.add_child(line)

	var caret := TerminalWindow.label(">" if selected else " ", TEXT_SIZE, Colors.PRIMARY)
	caret.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(caret)
	var name_label := TerminalWindow.label(row["label"], TEXT_SIZE, Colors.PRIMARY)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(name_label)
	line.add_child(TerminalWindow.spacer())

	if row.has("max_tier"):
		var pips := SegmentGauge.new()
		pips.custom_minimum_size.x = PIPS_WIDTH
		var top: int = row["max_tier"]
		pips.set_fill(float(row["tier"].call()) / top, Colors.PRIMARY, top)
		line.add_child(pips)

	var value: Callable = row.get("value", Callable())
	var text := str(value.call()) if value.is_valid() else ("<>" if row["arrows"] else "RUN")
	var value_label := TerminalWindow.label(text, TEXT_SIZE, Colors.TEXT if value.is_valid() else Colors.PRIMARY_DIM)
	value_label.custom_minimum_size.x = VALUE_WIDTH
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(value_label)
	return panel


# --- Open / close ------------------------------------------------------------

func open() -> void:
	gs = get_tree().get_first_node_in_group("game_state") as GameState
	visible = true
	get_tree().paused = true
	_build_sections()
	_frame.animate_in()


func close() -> void:
	if not visible:
		return
	visible = false
	# A pausing transmission, or the pause menu behind us, owns the pause instead.
	# (Untyped on purpose: PauseMenu names DevPanel, and two class_names that name
	# each other break the script class cache.)
	var pause_menu := get_tree().get_first_node_in_group("pause_menu") as CanvasItem
	var held: bool = RobotRadio.is_pausing() or (pause_menu != null and pause_menu.visible)
	if not held:
		get_tree().paused = false
	closed.emit()


## Only openable mid-flight: the menus have no state worth editing, and pausing
## over the start menu would wedge it.
func can_open() -> bool:
	var main := get_tree().get_first_node_in_group("main")
	return main != null and main.has_method("is_playing") and main.is_playing()


# --- Input -------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := (event as InputEventKey).keycode

	if not visible:
		if (key == KEY_F1 or key == KEY_QUOTELEFT) and can_open():
			open()
			get_viewport().set_input_as_handled()
		return

	match key:
		KEY_F1, KEY_QUOTELEFT, KEY_ESCAPE:
			close()
		KEY_TAB:
			_cycle_section(-1 if event.shift_pressed else 1)
		KEY_UP:
			_move_selection(-1)
		KEY_DOWN:
			_move_selection(1)
		KEY_LEFT:
			_activate(-1)
		KEY_RIGHT:
			_activate(1)
		KEY_ENTER, KEY_KP_ENTER:
			_activate(0)
		_:
			return
	get_viewport().set_input_as_handled()


func _cycle_section(direction: int) -> void:
	if _sections.is_empty():
		return
	_section_index = (_section_index + direction + _sections.size()) % _sections.size()
	_selected = 0
	_rebuild_rows()


func _move_selection(direction: int) -> void:
	if _rows.is_empty():
		return
	_selected = (_selected + direction + _rows.size()) % _rows.size()
	_refresh()


## `direction` is -1/+1 from the arrows, 0 from ENTER. Rows that take no arrows
## (plain actions) only answer to ENTER.
func _activate(direction: int) -> void:
	if _selected < 0 or _selected >= _rows.size():
		return
	var row := _rows[_selected]
	if direction != 0 and not row["arrows"]:
		return
	row["act"].call(direction)
	if is_instance_valid(self) and visible:
		_rebuild_rows()


# --- Sections ----------------------------------------------------------------

func _build_sections() -> void:
	_sections = [
		{"name": "SHIP", "build": _ship_rows},
		{"name": "GRAVITY", "build": _gravity_rows},
		{"name": "UPGRADES", "build": _upgrade_rows},
		{"name": "PROGRESS", "build": _progress_rows},
		{"name": "WARP", "build": _warp_rows},
		{"name": "SAVE", "build": _save_rows},
	]
	_section_index = clampi(_section_index, 0, _sections.size() - 1)
	_rebuild_rows()


func _rebuild_rows() -> void:
	_rows = _sections[_section_index]["build"].call()
	_selected = clampi(_selected, 0, maxi(_rows.size() - 1, 0))
	_refresh()


func _refresh() -> void:
	_section_title.text = TerminalWindow.spaced(_sections[_section_index]["name"])

	for child in _section_box.get_children():
		child.queue_free()
	for i in _sections.size():
		var picked := i == _section_index
		var name_text: String = _sections[i]["name"]
		var label := TerminalWindow.label(
			("> " if picked else "  ") + name_text,
			TEXT_SIZE,
			Colors.PRIMARY if picked else Colors.PRIMARY_DIM
		)
		_section_box.add_child(label)

	for child in _row_box.get_children():
		child.queue_free()
	_row_nodes.clear()
	for i in _rows.size():
		var node := _make_row(_rows[i], i == _selected)
		_row_box.add_child(node)
		_row_nodes.append(node)

	var note: String = _rows[_selected].get("note", "") if not _rows.is_empty() else ""
	_note.text = note
	_scroll_to_selection()


func _scroll_to_selection() -> void:
	if _selected < 0 or _selected >= _row_nodes.size():
		return
	var node := _row_nodes[_selected]
	await get_tree().process_frame
	if is_instance_valid(node) and is_instance_valid(_scroll):
		_scroll.ensure_control_visible(node)


# --- Row builders ------------------------------------------------------------

## A row the arrows nudge and ENTER tops out. `act` takes -1 / +1 / 0 (ENTER).
func _value_row(label: String, note: String, value: Callable, act: Callable) -> Dictionary:
	return {"label": label, "note": note, "value": value, "act": act, "arrows": true}


## A row that only runs on ENTER.
func _action_row(label: String, note: String, act: Callable) -> Dictionary:
	return {"label": label, "note": note, "act": func(_d: int) -> void: act.call(), "arrows": false}


## An on/off flag: either arrow or ENTER flips it.
func _toggle_row(label: String, note: String, read: Callable, write: Callable) -> Dictionary:
	return _value_row(
		label,
		note,
		func() -> String: return "ON" if read.call() else "OFF",
		func(direction: int) -> void:
			write.call(not read.call() if direction == 0 else direction > 0)
	)


func _ship() -> Ship:
	return get_tree().get_first_node_in_group("ship") as Ship


# --- SHIP --------------------------------------------------------------------

func _ship_rows() -> Array[Dictionary]:
	var ship := _ship()
	if ship == null:
		return [] as Array[Dictionary]
	var rows: Array[Dictionary] = []

	rows.append(_value_row(
		"FUEL",
		"Arrows move the tank a tenth at a time, ENTER fills it.",
		func() -> String: return "%d / %d" % [roundi(ship.fuel), roundi(ship.max_fuel)],
		func(direction: int) -> void:
			ship.fuel = ship.max_fuel if direction == 0 \
				else clampf(ship.fuel + direction * ship.max_fuel * GAUGE_STEP, 0.0, ship.max_fuel)
			ship.fuel_changed.emit()
	))

	rows.append(_value_row(
		"HULL",
		"Arrows take or give back a tenth of the plating, ENTER repairs it.",
		func() -> String: return "%d / %d" % [roundi(ship.hull_strength), roundi(ship.max_hull)],
		func(direction: int) -> void:
			ship.hull_strength = ship.max_hull if direction == 0 \
				else clampf(ship.hull_strength + direction * ship.max_hull * GAUGE_STEP, 0.0, ship.max_hull)
	))

	rows.append(_value_row(
		"HOLD",
		"RIGHT or ENTER packs the hold with gems; LEFT dumps it.",
		func() -> String: return "%d / %d" % [roundi(InventoryManager.get_total_weight()), roundi(ship.max_cargo_weight)],
		func(direction: int) -> void:
			if direction < 0:
				InventoryManager.clear_inventory()
			else:
				_fill_hold(ship)
			ship.update_mass_from_cargo()
	))

	rows.append(_value_row(
		"CREDITS",
		"Arrows move the balance by %d; ENTER adds %d." % [CREDIT_STEP, CREDIT_JUMP],
		func() -> String: return str(gs.credits) if gs else "-",
		func(direction: int) -> void:
			if gs:
				gs.credits = maxi(0, gs.credits + (CREDIT_JUMP if direction == 0 else direction * CREDIT_STEP))
	))

	rows.append(_toggle_row(
		"NO DAMAGE",
		"The hull stops taking hits, so a landing can be got wrong on purpose.",
		func() -> bool: return ship.dev_invulnerable,
		func(on: bool) -> void: ship.dev_invulnerable = on
	))

	rows.append(_toggle_row(
		"INFINITE FUEL",
		"Thrust stops drawing on the tank. The readout stays where it is.",
		func() -> bool: return ship.dev_infinite_fuel,
		func(on: bool) -> void: ship.dev_infinite_fuel = on
	))

	rows.append(_action_row(
		"SPAWN FREIGHT",
		"A test piece of Freight with its Lug just ahead of the nose. SPACE clamps it.",
		func() -> void:
			Freight.spawn_ahead_of(ship)
			close()
	))

	rows.append(_action_row(
		"STRAND SHIP",
		"Empties the tank, which is what puts the abandon-ship call on the radio.",
		func() -> void:
			ship.fuel = 0.0
			ship.fuel_changed.emit()
			ship.fuel_depleted.emit()
			close()
	))

	rows.append(_action_row(
		"DESTROY SHIP",
		"Blows the ship up, straight to the game-over call.",
		func() -> void:
			ship.dev_invulnerable = false
			ship.explode()
			close()
	))
	return rows


## Pack the hold to capacity with plain gems (one hold unit each).
func _fill_hold(ship: Ship) -> void:
	var room := ship.max_cargo_weight - InventoryManager.get_total_weight()
	var id := GemData.item_id(GemData.Tier.GEM)
	var each := InventoryManager.get_item_weight(id)
	if each <= 0.0 or room < each:
		return
	InventoryManager.add_item(id, floori(room / each))


# --- UPGRADES ----------------------------------------------------------------

func _upgrade_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if gs == null:
		return rows
	for track in UPGRADE_TRACKS:
		var path: String = track[0]
		var top: int = track[2]
		var row := _value_row(
			track[1],
			"Arrows step the tier, ENTER fits the top one. The ship is refitted from scratch.",
			func() -> String: return "TIER %d / %d" % [gs.get_upgrade_level(path), top],
			func(direction: int) -> void:
				var tier := top if direction == 0 else clampi(gs.get_upgrade_level(path) + direction, 0, top)
				_set_upgrade_tier(path, tier)
		)
		row["tier"] = func() -> int: return gs.get_upgrade_level(path)
		row["max_tier"] = top
		rows.append(row)

	rows.append(_toggle_row(
		"DRONE BAY",
		"The bay's own flag. Nothing sells it yet, so this is the only way to hold one.",
		func() -> bool: return gs.has_drone_bay,
		func(on: bool) -> void: gs.has_drone_bay = on
	))
	return rows


## Set a track's tier and refit the ship from the whole upgrade table, the way a
## load does. Unlock flags are cleared first so stepping a track back clears them.
func _set_upgrade_tier(path: String, tier: int) -> void:
	gs.set_upgrade_level(path, tier)
	var drone_bay := gs.has_drone_bay
	gs.has_planet_scanner = false
	gs.has_drone_bay = false
	var ship := _ship()
	if ship:
		ship.reapply_all_upgrades(gs)
	gs.has_drone_bay = gs.has_drone_bay or drone_bay


# --- PROGRESS ----------------------------------------------------------------

func _progress_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if gs == null:
		return rows

	rows.append(_value_row(
		"MODULES ONLINE",
		"Powers Gates in order, free. This is the number the Titan reads.",
		func() -> String: return "%d / %d" % [gs.titan_influence(), Gate.MODULE_COUNT],
		func(direction: int) -> void:
			var count := Gate.MODULE_COUNT if direction == 0 \
				else clampi(gs.titan_influence() + direction, 0, Gate.MODULE_COUNT)
			_set_modules(count)
	))

	rows.append(_action_row(
		"SR-7 WHOLE",
		"Seats every Section and pushes the wing true: the station whole and dark, the core listening.",
		func() -> void: Playtest.seat_sr7()
	))

	rows.append(_toggle_row(
		"SR-7 CORE",
		"Cold-started: the station powered and UNIT-7 awake. OFF puts the core back cold.",
		func() -> bool: return gs.core_started,
		func(on: bool) -> void:
			# A running core means every piece is home: it does not listen until the station
			# is whole (CoreHousing.listens), so turning it on seats them too. Otherwise the
			# save keeps a lit station with its Sections still floating outside it.
			if on:
				Playtest.seat_sr7()
			gs.core_started = on
			RobotRadio.guide_awake = on
			get_tree().call_group("core_housing", "refresh")
			get_tree().call_group("station_power", "refresh")
	))

	rows.append(_value_row(
		"GATES NAMED",
		"RIGHT or ENTER names every Gate; LEFT puts them all back to ? ? ?.",
		func() -> String: return "%d / %d" % [gs.identified_gates.size(), get_tree().get_nodes_in_group("gates").size()],
		func(direction: int) -> void:
			gs.identified_gates.clear()
			if direction >= 0:
				for gate in get_tree().get_nodes_in_group("gates"):
					gs.mark_gate_identified((gate as Gate).save_key())
	))

	rows.append(_value_row(
		"PLANETS SCANNED",
		"RIGHT or ENTER maps every planet; LEFT wipes the survey.",
		func() -> String: return "%d / %d" % [gs.scanned_planets.size(), _scannable_planets().size()],
		func(direction: int) -> void:
			gs.scanned_planets.clear()
			if direction >= 0:
				for planet in _scannable_planets():
					gs.mark_planet_scanned(planet.save_key())
	))

	rows.append(_value_row(
		"DEATHS",
		"The death counter. Nothing shows it, but the save carries it.",
		func() -> String: return str(gs.death_count),
		func(direction: int) -> void:
			gs.death_count = maxi(0, gs.death_count + (0 if direction == 0 else direction))
	))

	rows.append(_action_row(
		"REFILL ORE SEAMS",
		"Clears every seam's regrow timer, so all of them can be harvested again.",
		func() -> void: gs.spent_ore.clear()
	))

	rows.append(_action_row(
		"RESET RADIO TIPS",
		"Forgets the show-once transmissions, so the tutorial lines play again.",
		func() -> void: RobotRadio.reset()
	))

	rows.append(_action_row(
		"RESET VOID CLOCK",
		"Puts the Void's depth and shroud back to zero.",
		func() -> void: VoidZone.reset()
	))
	return rows


## Every Gate that stands for a Module, in save-key order so a count maps to the
## same set of Gates each time. The Core's Gate is not a Module.
func _module_gates() -> Array[Gate]:
	var gates: Array[Gate] = []
	for node in get_tree().get_nodes_in_group("gates"):
		var gate := node as Gate
		if gate and not gate.is_core:
			gates.append(gate)
	gates.sort_custom(func(a: Gate, b: Gate) -> bool: return a.save_key() < b.save_key())
	return gates


func _set_modules(count: int) -> void:
	gs.powered_gates.clear()
	var gates := _module_gates()
	for i in mini(count, gates.size()):
		gs.mark_gate_powered(gates[i].save_key())


func _scannable_planets() -> Array[Planet]:
	var planets: Array[Planet] = []
	for node in get_tree().get_nodes_in_group("planets"):
		var planet := node as Planet
		if planet and planet.planet_type != Planet.PlanetType.SUN:
			planets.append(planet)
	return planets


# --- GRAVITY -----------------------------------------------------------------

## Tune gravity by feel: the whole system at once, or one Body at a time. Every row moves
## `Planet.dev_gravity_scale` or a Body's `density_trim` and then recomputes its mass, so
## the Record and the pull the ship flies against stay the same number (docs/adr/0004).
## Nothing here is saved - it is for finding a number to put in the scene, not for keeping.
func _gravity_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var bodies := _bodies_by_size()
	if bodies.is_empty():
		return rows

	rows.append(_value_row(
		"ALL BODIES",
		"Arrows scale every Body's pull by %.2fx a step; ENTER puts it back to 1.00." % GRAVITY_STEP,
		func() -> String: return "x%.2f" % Planet.dev_gravity_scale,
		func(direction: int) -> void:
			Planet.dev_gravity_scale = 1.0 if direction == 0 \
				else _gravity_step(Planet.dev_gravity_scale, direction)
			for body in _bodies_by_size():
				body.refresh_mass()
	))

	for node in bodies:
		var planet := node
		rows.append(_value_row(
			planet.planet_name.to_upper(),
			"%s, %d px across. Arrows move this Body alone; ENTER puts it back to its class weight. Trim x%.2f." % [
				PlanetScan.type_name(planet.planet_type), roundi(planet.radius), planet.density_trim],
			func() -> String: return "%s  %d%%" % [PlanetScan.gravity(planet), roundi(_surface_pull_percent(planet))],
			func(direction: int) -> void:
				planet.density_trim = 1.0 if direction == 0 \
					else _gravity_step(planet.density_trim, direction)
				planet.refresh_mass()
		))

	rows.append(_action_row(
		"RESET ALL",
		"Puts the scale and every Body back to the weight the scene ships with.",
		func() -> void:
			Planet.dev_gravity_scale = 1.0
			for body in _bodies_by_size():
				body.density_trim = 1.0
				body.refresh_mass()
	))
	return rows


func _gravity_step(value: float, direction: int) -> float:
	var moved := value * (GRAVITY_STEP if direction > 0 else 1.0 / GRAVITY_STEP)
	return clampf(moved, GRAVITY_LIMIT.x, GRAVITY_LIMIT.y)


## Every Body, widest first, so the list reads down the way the gravity rule does.
func _bodies_by_size() -> Array[Planet]:
	var bodies: Array[Planet] = []
	for node in get_tree().get_nodes_in_group("planets"):
		var planet := node as Planet
		if planet:
			bodies.append(planet)
	bodies.sort_custom(func(a: Planet, b: Planet) -> bool: return a.radius > b.radius)
	return bodies


## Pull at the surface as a percentage of the ship's base thrust. G says what the Record
## reads; this says whether the Body will actually feel heavy to fly against.
func _surface_pull_percent(planet: Planet) -> float:
	var ship := _ship()
	if ship == null or ship.thrust_power <= 0.0:
		return 0.0
	var pull: float = planet._get_gravity_strength() / (planet.radius * planet.radius)
	return 100.0 * pull / ship.thrust_power


# --- WARP --------------------------------------------------------------------

func _warp_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if _ship() == null:
		return rows

	rows.append(_action_row(
		"HOME PORT (DOCK)",
		"Warps to Rook's port and docks, as if the ship had flown in and landed.",
		func() -> void: _warp(func() -> void: Playtest.redock())
	))

	for node in get_tree().get_nodes_in_group("gates"):
		var gate := node as Gate
		if gate == null or gate.parent_planet == null:
			continue
		var planet_name := gate.parent_planet.name
		rows.append(_action_row(
			"CORE GATE" if gate.is_core else "GATE: %s" % planet_name.to_upper(),
			"Parks on the approach to that Gate's cradle, lined up and matched to its orbit.",
			func() -> void: _warp(func() -> void: Playtest.park_at_gate(planet_name))
		))

	for planet in _scannable_planets():
		var planet_name := planet.name
		var distance := planet.scan_radius() * ORBIT_DISTANCE
		rows.append(_action_row(
			"ORBIT: %s" % planet_name.to_upper(),
			"Drops the ship into a circular orbit just clear of the surface.",
			func() -> void: _warp(func() -> void: Playtest.park_near_planet(planet_name, distance, 180.0, true))
		))

	rows.append(_action_row(
		"VOID EDGE",
		"Warps just past the last orbit, where the Void starts its clock.",
		func() -> void: _warp(_warp_to_void)
	))
	return rows


## Close first: the tree has to be running for the physics server to take the new
## transform, rather than sitting on a frozen one until the panel is dismissed.
func _warp(move: Callable) -> void:
	close()
	move.call()


func _warp_to_void() -> void:
	var sun: Node2D = null
	for node in get_tree().get_nodes_in_group("planets"):
		var planet := node as Planet
		if planet and planet.planet_type == Planet.PlanetType.SUN:
			sun = planet
			break
	var origin := sun.global_position if sun else Vector2.ZERO
	var ship := _ship()
	var direction := (ship.global_position - origin).normalized() if ship else Vector2.RIGHT
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	Playtest.warp_to(origin + direction * (VoidZone.EDGE_RADIUS + VOID_OVERSHOOT))


# --- SAVE --------------------------------------------------------------------

func _save_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	rows.append(_action_row(
		"SAVE NOW",
		"Writes the full save, the same one docking writes.",
		func() -> void:
			if gs:
				Save.save(gs, _ship())
	))
	rows.append(_action_row(
		"RELOAD SAVE",
		"Reloads the world from the save, as CONTINUE does from the start menu.",
		func() -> void:
			close()
			var main := get_tree().get_first_node_in_group("main")
			if main and main.has_method("load_game") and Save.save_exists():
				main.load_game()
	))
	rows.append(_action_row(
		"DELETE SAVE",
		"Removes the save file. The run in front of you keeps going.",
		func() -> void: DirAccess.remove_absolute(Playtest.save_path())
	))
	rows.append(_action_row(
		"RESET ALL STATE",
		"Credits, upgrades, hold and every flag back to a fresh run.",
		func() -> void:
			if gs:
				gs.reset_all_state()
			var ship := _ship()
			if ship:
				ship.reset_to_initial_state()
			RobotRadio.reset()
			VoidZone.reset()
	))
	return rows
