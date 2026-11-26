extends GdUnitTestSuite

## The current goal (Objectives.current) climbs one rung of the ladder per thing done, read
## off the Progress ledger alone, so a continue always lands on the right one.

const VELD_GATE := {"name": "Veld", "cost": 600}
const UNNAMED_GATE := {"name": "", "cost": 600}


func _seat_sections(p: Progress, n: int) -> void:
	var ids := Sections.DATA.keys()
	for i in n:
		p.mark(Progress.SEATED_SECTIONS, ids[i])


func _station_whole(p: Progress) -> void:
	_seat_sections(p, Sections.DATA.size())
	p.mark(Progress.SEATED_SECTIONS, Sections.SOLAR_ARRAY_2)


func _core_started(p: Progress) -> void:
	_station_whole(p)
	p.flag(Progress.CORE_STARTED)


func _bay_fitted(p: Progress) -> void:
	_core_started(p)
	p.mark(Progress.IDENTIFIED_WRECKS, "hauler")
	p.mark(Progress.FITTED_COMPONENTS, Components.CARGO_BAY)


func _goal(p: Progress, cradled := PackedStringArray(), stores := 0, gate := VELD_GATE) -> Dictionary:
	return Objectives.current(p, cradled, stores, gate)


func test_a_new_game_returns_the_sections() -> void:
	var g := _goal(Progress.new())
	assert_str(g["text"]).is_equal(Objectives.RETURN_SECTIONS)
	assert_str(g["detail"]).is_equal("0/3")


func test_the_count_climbs_as_sections_are_seated() -> void:
	var p := Progress.new()
	_seat_sections(p, 2)
	assert_str(_goal(p)["detail"]).is_equal("2/3")


func test_the_wing_pushed_home_first_still_waits_on_the_sections() -> void:
	var p := Progress.new()
	p.mark(Progress.SEATED_SECTIONS, Sections.SOLAR_ARRAY_2)
	assert_str(_goal(p)["text"]).is_equal(Objectives.RETURN_SECTIONS)


func test_all_three_seated_asks_for_the_wing() -> void:
	var p := Progress.new()
	_seat_sections(p, 3)
	assert_str(_goal(p)["text"]).is_equal(Objectives.PUSH_WING)
	assert_str(_goal(p)["detail"]).is_empty()


func test_a_whole_station_asks_for_the_core() -> void:
	var p := Progress.new()
	_station_whole(p)
	assert_str(_goal(p)["text"]).is_equal(Objectives.WAKE_CORE)


func test_a_running_core_sends_the_pilot_to_veld() -> void:
	var p := Progress.new()
	_core_started(p)
	var g := _goal(p)
	assert_str(g["text"]).is_equal(Objectives.FIND_DISH)
	assert_str(g["detail"]).is_equal("VELD")


func test_the_named_hauler_asks_for_the_cargo_bay() -> void:
	var p := Progress.new()
	_core_started(p)
	p.mark(Progress.IDENTIFIED_WRECKS, "hauler")
	assert_str(_goal(p)["text"]).is_equal(Objectives.BRING_CARGO_BAY)


func test_the_cargo_bay_in_the_cradle_asks_to_fit_it() -> void:
	var p := Progress.new()
	_core_started(p)
	p.mark(Progress.IDENTIFIED_WRECKS, "hauler")
	assert_str(_goal(p, PackedStringArray([Components.CARGO_BAY]))["text"]).is_equal(Objectives.FIT_CARGO_BAY)


func test_a_cargo_bay_home_skips_the_hauler_even_unnamed() -> void:
	var p := Progress.new()
	_core_started(p)
	assert_str(_goal(p, PackedStringArray([Components.CARGO_BAY]))["text"]).is_equal(Objectives.FIT_CARGO_BAY)


func test_a_cargo_bay_taken_off_again_asks_to_fit_it() -> void:
	var p := Progress.new()
	_bay_fitted(p)
	assert_str(_goal(p, PackedStringArray([Components.CARGO_BAY]))["text"]).is_equal(Objectives.FIT_CARGO_BAY)


func test_a_fitted_hold_works_toward_the_named_gate() -> void:
	var p := Progress.new()
	_bay_fitted(p)
	var g := _goal(p, PackedStringArray(), 320)
	assert_str(g["text"]).is_equal("POWER VELD'S GATE")
	assert_str(g["detail"]).is_equal("320/600 ST")


func test_an_unidentified_gate_is_just_a_gate() -> void:
	var p := Progress.new()
	_bay_fitted(p)
	assert_str(_goal(p, PackedStringArray(), 0, UNNAMED_GATE)["text"]).is_equal(Objectives.POWER_A_GATE)


func test_stores_past_the_cost_read_as_enough() -> void:
	var p := Progress.new()
	_bay_fitted(p)
	assert_str(_goal(p, PackedStringArray(), 900)["detail"]).is_equal("600/600 ST")


func test_every_module_online_says_the_core_is_waiting() -> void:
	var p := Progress.new()
	_bay_fitted(p)
	for key in ["a", "b", "c", "d", "e"]:
		p.mark(Progress.POWERED_GATES, key)
	assert_str(_goal(p, PackedStringArray(), 0, {})["text"]).is_equal(Objectives.MODULES_ONLINE)


func test_no_gates_left_short_of_five_is_no_goal() -> void:
	var p := Progress.new()
	_bay_fitted(p)
	assert_str(_goal(p, PackedStringArray(), 0, {})["text"]).is_empty()
