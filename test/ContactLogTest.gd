extends GdUnitTestSuite

## What a Sweep reads types into the HUD's corner, holds, and fades (ui/ContactLog.gd).

var _log: ContactLog

func before_test() -> void:
	_log = auto_free(ContactLog.new()) as ContactLog
	add_child(_log)

func _readout(title: String) -> SweepReadout:
	var owner_node := auto_free(Node2D.new()) as Node2D
	add_child(owner_node)
	var r := SweepReadout.new()
	r.heading = "MOUNT"
	r.title = title
	owner_node.add_child(r)
	return r

func _rows() -> Array:
	return [ReadoutRow.make("STATE", "EMPTY")]

## Long enough for any entry here to have typed.
func _type_out() -> void:
	_log._process(2.0)


func test_a_read_types_out_its_heading_and_rows() -> void:
	_log.show_read(_readout("FUEL TANK"), 1, _rows())
	assert_bool(_log.visible).is_true()
	_log._process(0.05)
	assert_str(_log.text()).override_failure_message("the heading has started typing").is_not_empty()
	assert_bool(_log.text().contains("STATE")).override_failure_message("rows type after the heading").is_false()
	_type_out()
	var text := _log.text()
	assert_bool(text.begins_with("MOUNT / FUEL TANK")).is_true()
	assert_bool(text.contains("STATE")).is_true()
	assert_bool(text.ends_with("EMPTY")).is_true()


func test_rows_end_in_the_diagnostics_column() -> void:
	var lines := ContactLog.entry_lines("MOUNT", "FUEL TANK", _rows())
	var row := ""
	for seg in lines[1]:
		row += seg[0]
	assert_int(row.length()).is_equal(BootChecklist.LABEL_COL + BootChecklist.KEY_COL + BootChecklist.STAMP_OK.length())


func test_reading_the_same_thing_again_types_over_its_entry() -> void:
	var r := _readout("FUEL TANK")
	_log.show_read(r, 1, _rows())
	_log.show_read(r, 2, [ReadoutRow.make("STATE", "EMPTY"), ReadoutRow.make("EDGE", "TORCH CUT", 2)])
	_type_out()
	assert_int(_log._entries.size()).is_equal(1)
	assert_bool(_log.text().contains("TORCH CUT")).is_true()


func test_reading_the_same_thing_again_leaves_it_up() -> void:
	var r := _readout("FUEL TANK")
	_log.show_read(r, 1, _rows())
	_type_out()
	var typed := _log.text()
	_log._process(ContactLog.HOLD - 1.0)
	_log.show_read(r, 1, _rows())
	assert_str(_log.text()).override_failure_message("not wiped to retype").is_equal(typed)
	_log._process(0.05)
	assert_str(_log.text()).is_equal(typed)
	_log._process(ContactLog.HOLD - 0.5)
	assert_int(_log._entries.size()).override_failure_message("its hold started over").is_equal(1)


func test_a_deeper_read_types_on_only_what_is_new() -> void:
	var r := _readout("FUEL TANK")
	_log.show_read(r, 1, _rows())
	_type_out()
	var typed := _log.text()
	_log.show_read(r, 2, [ReadoutRow.make("STATE", "EMPTY"), ReadoutRow.make("EDGE", "TORCH CUT", 2)])
	_log._process(0.05)
	assert_bool(_log.text().begins_with(typed)).override_failure_message("what was typed stays").is_true()
	assert_bool(_log.text().contains("TORCH CUT")).is_false()
	_type_out()
	assert_bool(_log.text().contains("TORCH CUT")).is_true()


func test_too_many_reads_drop_the_oldest() -> void:
	for i in ContactLog.MAX_ENTRIES + 1:
		_log.show_read(_readout("PART %d" % i), 1, _rows())
	_type_out()
	assert_int(_log._entries.size()).is_equal(ContactLog.MAX_ENTRIES)
	assert_bool(_log.text().contains("PART 0")).is_false()
	assert_bool(_log.text().contains("PART %d" % ContactLog.MAX_ENTRIES)).is_true()


func test_an_entry_holds_then_fades_away() -> void:
	_log.show_read(_readout("FUEL TANK"), 1, _rows())
	_type_out()
	_log._process(ContactLog.HOLD - 2.0)
	assert_int(_log._entries.size()).override_failure_message("still holding").is_equal(1)
	_log._process(2.0 + ContactLog.FADE_TIME)
	assert_int(_log._entries.size()).is_equal(0)
	assert_bool(_log.visible).is_false()


func test_it_answers_the_event_bus() -> void:
	EventBus.readout_swept.emit(_readout("SOLAR ARRAY"), 1, _rows())
	_type_out()
	assert_bool(_log.text().begins_with("MOUNT / SOLAR ARRAY")).is_true()


func test_something_of_the_titans_is_typed_in_its_purple() -> void:
	var lines := ContactLog.entry_lines("#%&$", "", _rows(), true)
	assert_object(lines[0][0][1]).is_equal(Colors.TITAN)
	assert_object(lines[1][0][1]).is_equal(Colors.TITAN)
	assert_object(lines[1][1][1]).override_failure_message("the leaders stay the ship's").is_equal(Colors.PRIMARY_DIM)
	assert_object(lines[1][2][1]).is_equal(Colors.TITAN)
