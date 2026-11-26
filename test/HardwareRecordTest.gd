extends GdUnitTestSuite

## The H A R D W A R E section of the Log's Records tab: one Record per thing the ship has
## read up close (ui/log/RecordsTab.gd).

var _gs: GameState

func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	_gs.set_process(false)
	add_child(_gs)

func _readout(key: String, title: String, category := "") -> Readout:
	var owner_node := auto_free(Node2D.new()) as Node2D
	add_child(owner_node)
	var r := Readout.new()
	r.key = key
	r.heading = "MOUNT"
	r.title = title
	r.category = category
	r.rows = [ReadoutRow.make("STATE", "EMPTY"), ReadoutRow.make("EDGE", "TORCH CUT"),
		ReadoutRow.make("FRACTURE", "NONE")]
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
	array.read()
	tank.read()
	var read := RecordsTab.read_hardware(get_tree(), _gs)
	assert_array(read.map(func(r: Dictionary) -> String: return r.key)).contains_exactly(["b", "a"])
	var text := _text_of(_records_tab())
	assert_bool(text.has("H A R D W A R E")).is_true()
	assert_bool(text.has("SOLAR ARRAY")).is_true()


func test_the_record_holds_every_row() -> void:
	_readout("a", "FUEL TANK").read()
	var text := _text_of(_records_tab())
	assert_bool(text.has(RecordsTab.hardware_line(ReadoutRow.make("EDGE", "TORCH CUT")))).is_true()
	assert_bool(text.has(RecordsTab.hardware_line(ReadoutRow.make("FRACTURE", "NONE")))).is_true()


func test_nothing_is_learned_from_the_undecipherable() -> void:
	var r := _readout("g", "")
	r.undecipherable = true
	r.read()
	assert_array(RecordsTab.read_hardware(get_tree(), _gs)).is_empty()


func test_the_cursor_runs_on_into_hardware() -> void:
	_readout("a", "FUEL TANK").read()
	_readout("b", "SOLAR ARRAY").read()
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
	tank.read()
	gauge.read()
	array.read()
	var filed := RecordsTab.file_hardware(RecordsTab.read_hardware(get_tree(), _gs))
	assert_array(filed.map(func(r: Dictionary) -> String: return r.key)) \
		.override_failure_message("a place's things together, read order within") \
		.contains_exactly(["a", "b", "c"])


func test_a_place_is_named_once_over_its_things() -> void:
	_readout("a", "FUEL TANK", "SR-7").read()
	_readout("b", "SOLAR ARRAY", "SR-7").read()
	var text := _text_of(_records_tab())
	assert_int(text.count("SR-7")).is_equal(1)
	assert_int(text.find("SR-7")).is_less(text.find("FUEL TANK"))


func test_the_cursor_follows_the_filed_order() -> void:
	var tank := _readout("a", "FUEL TANK", "SR-7")
	var gauge := _readout("c", "GAUGE")
	var array := _readout("b", "SOLAR ARRAY", "SR-7")
	tank.read()
	gauge.read()
	array.read()
	var tab := _records_tab()
	tab.handle_action(&"menu_down")
	assert_bool(_text_of(tab._detail).has("SOLAR ARRAY")) \
		.override_failure_message("the row under FUEL TANK is SOLAR ARRAY, not the one read next").is_true()
	assert_bool(_text_of(tab._detail).has("SR-7 / MOUNT")).is_true()


func test_a_kind_many_things_share_is_one_record_that_outlives_them() -> void:
	Readout.register_kind("test_kind", "SCRAP", "", "SALVAGE", [ReadoutRow.make("YIELD", "MOSTLY SHARDS")])
	var first := _readout("test_kind", "", "SALVAGE")
	var second := _readout("test_kind", "", "SALVAGE")
	first.read()
	second.read()
	var read := RecordsTab.read_hardware(get_tree(), _gs)
	assert_int(read.size()).override_failure_message("one Record for the kind").is_equal(1)
	assert_str(read[0].heading).is_equal("SCRAP")
	first.get_parent().free()
	second.get_parent().free()
	read = RecordsTab.read_hardware(get_tree(), _gs)
	assert_int(read.size()).override_failure_message("kept with no piece left in the world").is_equal(1)
	assert_str(read[0].rows[0].value).is_equal("MOSTLY SHARDS")
