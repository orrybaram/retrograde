class_name LogUI
extends Control

## The Log: the player's own screen, kept by the ship, not by the Titan. A tabbed
## terminal window that opens on the Hold; the Records tab holds one entry per thing
## the player has reached. Opens and closes with "I" (ESC also closes; see Main).
##
## No Automaton speaks from inside the Log — it is the player's own instrument, read
## alone. UNIT-7 is met at SR-7 and heard on the radio, never carried around in a menu.
##
## Built in code from TerminalWindow + LogTab subclasses; the .tscn is just the root.
## Adding a tab is one LogTab subclass plus one entry in TABS.

signal dialogue_closed

const WINDOW_SIZE := Vector2(880, 440)
## The tabs, in notch order. The first one is what the Log opens on.
const TABS := [
	preload("res://ui/log/ShipTab.gd"),
	preload("res://ui/log/RecordsTab.gd"),
]

var gs: GameState = null
var inventory_manager: InventoryManager = null

var _frame: TerminalWindow
var _tabs: Array[LogTab] = []
var _active := 0
var _ship: Ship = null


func _ready() -> void:
	visible = false
	add_to_group("log_ui")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	gs = get_tree().get_first_node_in_group("game_state") as GameState
	inventory_manager = get_node_or_null("/root/InventoryManager") as InventoryManager

	# Live updates while open
	if gs:
		gs.credits_changed.connect(_refresh)
		gs.upgrade_level_changed.connect(_refresh)
	if inventory_manager:
		inventory_manager.inventory_changed.connect(_refresh)
	# A scan landing while the Log is up fills that Body's Record where the player can
	# see it, without closing and reopening.
	EventBus.planet_scanned.connect(_refresh)
	_connect_ship()


func open_log() -> void:
	_connect_ship()
	visible = true
	_show_tab(0)
	_frame.animate_in()


func close_log() -> void:
	visible = false
	if _tabs.is_empty():
		return
	_tabs[_active].visible = false
	_tabs[_active].on_hidden()
	dialogue_closed.emit()


## Title of the tab currently up, e.g. "SHIP". For tests and playtests.
func active_tab_title() -> String:
	return _tabs[_active].tab_title() if not _tabs.is_empty() else ""


# --- Layout ------------------------------------------------------------------

func _build() -> void:
	_frame = TerminalWindow.new(WINDOW_SIZE, TerminalWindow.spaced_title("LOG"), LogTab.SHELL_KEYS)
	add_child(_frame)

	var titles: Array[String] = []
	for script in TABS:
		var tab: LogTab = script.new()
		tab.visible = false
		_tabs.append(tab)
		_frame.body.add_child(tab)
		titles.append(tab.tab_title())
	_frame.add_tabs(titles)


## Open `index`'s tab: light its notch, hide the tab that was up, and hand the bottom
## border's hint over to the one now in front.
func _show_tab(index: int) -> void:
	if _tabs.is_empty():
		return
	var previous := _active
	_active = clampi(index, 0, _tabs.size() - 1)
	if previous != _active and _tabs[previous].visible:
		_tabs[previous].visible = false
		_tabs[previous].on_hidden()
	for i in _tabs.size():
		_tabs[i].visible = i == _active
	_frame.select_tab(_active)
	var tab := _tabs[_active]
	tab.refresh()
	tab.on_shown()
	_frame.set_hint(tab.hint())


# --- Content -----------------------------------------------------------------

## Signal args vary; ignore them.
func _refresh(_a: Variant = null, _b: Variant = null) -> void:
	if not visible or _tabs.is_empty():
		return
	_tabs[_active].refresh()


## The ship respawns on death, so re-resolve it whenever the Log opens.
func _connect_ship() -> void:
	var current := get_tree().get_first_node_in_group("ship") as Ship
	if current == _ship:
		return
	_ship = current
	if _ship and _ship.has_signal("fuel_changed") and not _ship.fuel_changed.is_connected(_refresh):
		_ship.fuel_changed.connect(_refresh)


# --- Input -------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key_event := event as InputEventKey
	var key := key_event.keycode
	# I and ESC stay with Main, which owns opening and closing.
	if key == KEY_I or key == KEY_ESCAPE:
		return
	if key == KEY_TAB:
		_cycle_tab(-1 if key_event.shift_pressed else 1)
		get_viewport().set_input_as_handled()
		return
	# Everything else is the active tab's to take. Nothing claims LEFT / RIGHT yet,
	# so they stay free for a future tab's adjustable rows.
	if not _tabs.is_empty() and _tabs[_active].handle_key(key):
		get_viewport().set_input_as_handled()


func _cycle_tab(direction: int) -> void:
	if _tabs.is_empty():
		return
	_show_tab((_active + direction + _tabs.size()) % _tabs.size())
