extends GdUnitTestSuite

## The Log's shell (ui/log/LogUI.gd): which tab is up, how TAB moves between them and
## what the bottom border says. The tabs' contents are their own business.

var _gs: GameState
var _log: LogUI


func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	_gs.set_process(false)
	add_child(_gs)


func after_test() -> void:
	InventoryManager.clear_inventory()


func _log_in_tree() -> LogUI:
	_log = auto_free(load("res://ui/log/LogUI.tscn").instantiate()) as LogUI
	add_child(_log)
	return _log


## TAB, with or without shift held, through the Log's own input path.
func _press_tab(shift := false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_TAB
	ev.physical_keycode = KEY_TAB
	ev.pressed = true
	ev.shift_pressed = shift
	_log._input(ev)


func test_opens_on_the_hold() -> void:
	var log_ui := _log_in_tree()
	log_ui.open_log()
	assert_bool(log_ui.visible).is_true()
	assert_str(log_ui.active_tab_title()).is_equal("HOLD")


func test_tab_moves_to_records_and_back() -> void:
	var log_ui := _log_in_tree()
	log_ui.open_log()
	_press_tab()
	assert_str(log_ui.active_tab_title()).is_equal("RECORDS")
	_press_tab()
	assert_str(log_ui.active_tab_title()).is_equal("HOLD")


func test_shift_tab_reverses() -> void:
	var log_ui := _log_in_tree()
	log_ui.open_log()
	_press_tab(true)
	assert_str(log_ui.active_tab_title()).is_equal("RECORDS")


## Only the tab that is up is lit; the rest of the notches stay dim. Which one the
## player is on has to be readable at a glance, so it is said three ways at once and
## each of them is worth holding onto.
func test_only_the_selected_notch_is_lit() -> void:
	var log_ui := _log_in_tree()
	log_ui.open_log()
	_assert_notch_lit(log_ui, 0, true)
	_assert_notch_lit(log_ui, 1, false)
	_press_tab()
	_assert_notch_lit(log_ui, 0, false)
	_assert_notch_lit(log_ui, 1, true)


## A selected tab is the brighter one, it wears the `>` of a selected control, and its
## notch is open at the bottom into the window; an unselected one is dim, unprefixed and
## closed off by a bottom edge, so the frame line reads as running straight through it.
func _assert_notch_lit(log_ui: LogUI, index: int, lit: bool) -> void:
	var notch: Label = log_ui._frame._tab_labels[index]
	assert_object(notch.get_theme_color("font_color")).is_equal(
			Colors.PRIMARY if lit else Colors.PRIMARY_DIM)
	assert_str(notch.text).starts_with(
			TerminalWindow.TAB_SELECTED_PREFIX if lit else TerminalWindow.TAB_UNSELECTED_PREFIX)
	var box: StyleBoxFlat = notch.get_theme_stylebox("normal")
	assert_int(box.border_width_bottom).is_equal(0 if lit else TerminalWindow.BORDER_WIDTH)


## A tab is a control, not a header, so its notch reads as a word rather than as the
## spaced letters the headings inside the tab use.
func test_a_notch_reads_as_a_label_not_a_heading() -> void:
	var log_ui := _log_in_tree()
	log_ui.open_log()
	assert_str(log_ui._frame._tab_labels[0].text).is_equal(
			TerminalWindow.TAB_SELECTED_PREFIX + "HOLD")
	assert_str(log_ui._frame._tab_labels[1].text).is_equal(
			TerminalWindow.TAB_UNSELECTED_PREFIX + "RECORDS")


## Closing on Records and reopening puts the player back on the Hold.
func test_reopens_on_the_hold() -> void:
	var log_ui := _log_in_tree()
	log_ui.open_log()
	_press_tab()
	log_ui.close_log()
	assert_bool(log_ui.visible).is_false()
	log_ui.open_log()
	assert_str(log_ui.active_tab_title()).is_equal("HOLD")


## The bottom border is the active tab's hint(), not a constant on the frame.
func test_hint_comes_from_the_active_tab() -> void:
	var log_ui := _log_in_tree()
	log_ui.open_log()
	assert_str(log_ui._frame._hint.text).is_equal(log_ui._tabs[0].hint())
	_press_tab()
	assert_str(log_ui._frame._hint.text).is_equal(log_ui._tabs[1].hint())


## The Log is the player's own instrument, read alone — no robot on this screen.
func test_no_robot_on_the_log() -> void:
	var log_ui := _log_in_tree()
	log_ui.open_log()
	assert_int(_count(log_ui, "RobotCard")).is_equal(0)
	assert_int(_count(log_ui, "RobotView")).is_equal(0)


## LEFT / RIGHT are unclaimed, so a future tab can take them for adjustable rows.
func test_left_and_right_stay_unclaimed() -> void:
	var log_ui := _log_in_tree()
	log_ui.open_log()
	for tab in log_ui._tabs:
		assert_bool(tab.handle_key(KEY_LEFT)).is_false()
		assert_bool(tab.handle_key(KEY_RIGHT)).is_false()


## A scan landing while the Log is up fills that Body's Record where the player can see
## it — no closing and reopening.
func test_a_scan_fills_the_record_while_the_log_is_open() -> void:
	var planet := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	planet.radius = 400.0
	planet.planet_type = Planet.PlanetType.ICE_GIANT
	planet.name = "Sonder"
	planet.planet_name = "Sonder"
	add_child(planet)
	_gs.mark_planet_visited(planet.save_key())
	var log_ui := _log_in_tree()
	log_ui.open_log()
	_press_tab()
	var records := log_ui._tabs[1] as RecordsTab
	assert_str(_text(records)).contains(RecordsTab.NO_SURVEY)

	_gs.mark_planet_scanned(planet.save_key())
	EventBus.planet_scanned.emit(planet)
	assert_str(_text(records)).not_contains(RecordsTab.NO_SURVEY)
	assert_str(_text(records)).contains(PlanetScan.summary_line(planet))


## Every Label's text under `node`, joined in tree order.
func _text(node: Node) -> String:
	var out := PackedStringArray()
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		out.append(_text(child))
	return "\n".join(out)


func _count(node: Node, class_string: String) -> int:
	var found := 0
	if node.get_script() != null and node.get_script().get_global_name() == class_string:
		found += 1
	for child in node.get_children():
		found += _count(child, class_string)
	return found
