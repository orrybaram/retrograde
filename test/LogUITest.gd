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
	assert_str(log_ui.active_tab_title()).is_equal("H O L D")


func test_tab_moves_to_records_and_back() -> void:
	var log_ui := _log_in_tree()
	log_ui.open_log()
	_press_tab()
	assert_str(log_ui.active_tab_title()).is_equal("R E C O R D S")
	_press_tab()
	assert_str(log_ui.active_tab_title()).is_equal("H O L D")


func test_shift_tab_reverses() -> void:
	var log_ui := _log_in_tree()
	log_ui.open_log()
	_press_tab(true)
	assert_str(log_ui.active_tab_title()).is_equal("R E C O R D S")


## Only the tab that is up is lit; the rest of the notches stay dim.
func test_only_the_selected_notch_is_lit() -> void:
	var log_ui := _log_in_tree()
	log_ui.open_log()
	assert_object(log_ui._notches[0].get_theme_color("font_color")).is_equal(Colors.PRIMARY)
	assert_object(log_ui._notches[1].get_theme_color("font_color")).is_equal(Colors.PRIMARY_DIM)
	_press_tab()
	assert_object(log_ui._notches[0].get_theme_color("font_color")).is_equal(Colors.PRIMARY_DIM)
	assert_object(log_ui._notches[1].get_theme_color("font_color")).is_equal(Colors.PRIMARY)


## Closing on Records and reopening puts the player back on the Hold.
func test_reopens_on_the_hold() -> void:
	var log_ui := _log_in_tree()
	log_ui.open_log()
	_press_tab()
	log_ui.close_log()
	assert_bool(log_ui.visible).is_false()
	log_ui.open_log()
	assert_str(log_ui.active_tab_title()).is_equal("H O L D")


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


func _count(node: Node, class_string: String) -> int:
	var found := 0
	if node.get_script() != null and node.get_script().get_global_name() == class_string:
		found += 1
	for child in node.get_children():
		found += _count(child, class_string)
	return found
