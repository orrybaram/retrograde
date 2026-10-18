extends GdUnitTestSuite

## The H A R D W A R E section of the Log's Records tab: one Record per thing a Sweep has
## read, as deep as it was read (ui/log/RecordsTab.gd, docs/SWEEP.md §10).

var _gs: GameState

func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	_gs.set_process(false)
	add_child(_gs)

func _readout(key: String, title: String, category := "") -> SweepReadout:
	var owner_node := auto_free(Node2D.new()) as Node2D
	add_child(owner_node)
	var r := SweepReadout.new()
	r.key = key
	r.heading = "MOUNT"
	r.title = title
	r.category = category
	r.rows = [ReadoutRow.make("STATE", "EMPTY"), ReadoutRow.make("EDGE", "TORCH CUT", 2),
		ReadoutRow.make("FRACTURE", "NONE", 3)]
	owner_node.add_child(r)
	return r

func _records_tab() -> RecordsTab:
	var tab := auto_free(RecordsTab.new()) as RecordsTab
	add_child(tab)
	tab.refresh()
	return tab

func _text_of(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is CanvasItem and not (node as CanvasItem).visible:
		return out
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		out.append_array(_text_of(child))
	return out


func test_nothing_read_no_section() -> void:
	_readout("a", "FUEL TANK")
	var tab := _records_tab()
	assert_bool(_text_of(tab).has("H A R D W A R E")).is_false()


func test_a_read_earns_a_record_in_the_order_read() -> void:
	var tank := _readout("a", "FUEL TANK")
	var array := _readout("b", "SOLAR ARRAY")
	array.read(1.0)
	tank.read(1.0)
	var read := RecordsTab.read_hardware(get_tree(), _gs)
	assert_array(read).contains_exactly([array, tank])
	var text := _text_of(_records_tab())
	assert_bool(text.has("H A R D W A R E")).is_true()
	assert_bool(text.has("SOLAR ARRAY")).is_true()


func test_the_record_holds_only_the_tiers_read() -> void:
	var tank := _readout("a", "FUEL TANK")
	tank.read(2.0)
	var text := _text_of(_records_tab())
	assert_bool(text.has(RecordsTab.hardware_line(ReadoutRow.make("EDGE", "TORCH CUT")))).is_true()
	assert_bool(text.any(func(t: String) -> bool: return t.contains("FRACTURE"))) \
		.override_failure_message("no row for a tier never read").is_false()


func test_nothing_is_learned_from_the_undecipherable() -> void:
	var r := _readout("g", "")
	r.undecipherable = true
	r.read(3.0)
	assert_array(RecordsTab.read_hardware(get_tree(), _gs)).is_empty()


func test_the_cursor_runs_on_into_hardware() -> void:
	_readout("a", "FUEL TANK").read(1.0)
	_readout("b", "SOLAR ARRAY").read(1.0)
	var tab := _records_tab()
	assert_int(tab._hardware_index()).is_equal(0)
	tab.handle_action(&"menu_down")
	assert_int(tab._hardware_index()).is_equal(1)
	tab.handle_action(&"menu_down")
	assert_int(tab._hardware_index()).override_failure_message("wraps back to the top").is_equal(0)


func test_hardware_is_filed_under_its_place_in_first_read_order() -> void:
	var tank := _readout("a", "FUEL TANK", "SR-7")
	var gauge := _readout("c", "GAUGE")
	var array := _readout("b", "SOLAR ARRAY", "SR-7")
	tank.read(1.0)
	gauge.read(1.0)
	array.read(1.0)
	var filed := RecordsTab.file_hardware(RecordsTab.read_hardware(get_tree(), _gs))
	assert_array(filed).override_failure_message("a place's things together, read order within") \
		.contains_exactly([tank, array, gauge])


func test_a_place_is_named_once_over_its_things() -> void:
	_readout("a", "FUEL TANK", "SR-7").read(1.0)
	_readout("b", "SOLAR ARRAY", "SR-7").read(1.0)
	var text := _text_of(_records_tab())
	assert_int(text.count("SR-7")).is_equal(1)
	assert_int(text.find("SR-7")).is_less(text.find("FUEL TANK"))


func test_the_cursor_follows_the_filed_order() -> void:
	var tank := _readout("a", "FUEL TANK", "SR-7")
	var gauge := _readout("c", "GAUGE")
	var array := _readout("b", "SOLAR ARRAY", "SR-7")
	tank.read(1.0)
	gauge.read(1.0)
	array.read(1.0)
	var tab := _records_tab()
	tab.handle_action(&"menu_down")
	assert_bool(_text_of(tab._detail).has("SOLAR ARRAY")) \
		.override_failure_message("the row under FUEL TANK is SOLAR ARRAY, not the one read next").is_true()
	assert_bool(_text_of(tab._detail).has("SR-7 / MOUNT")).is_true()
