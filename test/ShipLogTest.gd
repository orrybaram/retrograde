extends GdUnitTestSuite

## The ship's log (ShipLog, GameState.write_log): one line an entry, stamped with mission
## time, a status dot, saved; what writes to it on a new game, a find and a seating; the LOG
## tab listing it newest first; and the HUD's one cue that it changed (LogCue).

var _gs: GameState


func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	_gs.set_process(false)
	add_child(_gs)


func test_stamps_mission_time() -> void:
	assert_str(ShipLog.stamp(0.0)).is_equal("T+00:00")
	assert_str(ShipLog.stamp(100.4)).is_equal("T+01:40")
	assert_str(ShipLog.stamp(3725.0)).is_equal("T+1:02:05")


func test_status_is_a_colour_and_nothing_else() -> void:
	assert_object(ShipLog.status_color(ShipLog.ERR)).is_equal(Colors.DANGER)
	assert_object(ShipLog.status_color(ShipLog.WARN)).is_equal(Colors.PRIMARY)
	assert_object(ShipLog.status_color(ShipLog.INFO)).is_equal(Colors.TEXT_MUTED)


func test_new_until_seen() -> void:
	var log := ShipLog.new()
	log.add(1.0, ShipLog.SYS, "A", "B")
	assert_bool(log.is_new(0)).is_true()
	log.mark_seen()
	log.add(2.0, ShipLog.SYS, "C", "D")
	assert_bool(log.is_new(0)).is_false()
	assert_bool(log.is_new(1)).is_true()


func test_round_trips_through_a_save_all_seen() -> void:
	var log := ShipLog.new()
	log.add(12.5, ShipLog.SONAR, "SOLAR ARRAY", "LOCATED", ShipLog.INFO)
	log.add(13.0, ShipLog.SYS, "SR-7 STATUS", "CRITICAL", ShipLog.ERR)
	var back := ShipLog.from_array(log.to_array())
	assert_array(back.entries).is_equal(log.entries)
	assert_bool(back.is_new(1)).is_false()


func test_keeps_only_the_newest() -> void:
	var log := ShipLog.new()
	for i in ShipLog.MAX_ENTRIES + 5:
		log.add(float(i), ShipLog.SYS, "N", str(i))
	assert_int(log.entries.size()).is_equal(ShipLog.MAX_ENTRIES)
	assert_str(log.entries[0]["value"]).is_equal("5")


func test_a_new_game_opens_critical_with_three_missing() -> void:
	var written: Array = []
	var on_write := func(e: Dictionary) -> void: written.append(e)
	EventBus.ship_log_written.connect(on_write)
	_gs.open_ship_log()
	EventBus.ship_log_written.disconnect(on_write)
	assert_int(written.size()).is_equal(2)
	assert_str(ShipLogTab.line_text(written[0])).starts_with("SR-7 STATUS ").ends_with(" CRITICAL")
	assert_str(written[0]["status"]).is_equal(ShipLog.ERR)
	assert_str(written[1]["value"]).is_equal("3")
	assert_str(written[1]["status"]).is_equal(ShipLog.WARN)


func test_a_section_is_found_once_and_never_once_home() -> void:
	assert_bool(_gs.find_section(Sections.FUEL_TANK, "CONTACT")).is_true()
	assert_bool(_gs.find_section(Sections.FUEL_TANK, "LOCATED")).is_false()
	assert_int(_gs.ship_log.entries.size()).is_equal(1)
	assert_str(_gs.ship_log.entries[0]["source"]).is_equal(ShipLog.SONAR)
	_gs.progress.mark(Progress.SEATED_SECTIONS, Sections.DORSAL_ARM)
	assert_bool(_gs.find_section(Sections.DORSAL_ARM, "CONTACT")).is_false()
	assert_bool(_gs.find_section(Sections.SOLAR_ARRAY_2, "CONTACT")) \
		.override_failure_message("the wing is never missing").is_false()


func test_seating_logs_it_and_the_count() -> void:
	_gs.progress.mark(Progress.SEATED_SECTIONS, Sections.FUEL_TANK)
	EventBus.section_seated.emit(Sections.FUEL_TANK)
	var e := _gs.ship_log.entries
	assert_str(e[-2]["source"]).is_equal(ShipLog.MOUNT)
	assert_str(e[-2]["value"]).is_equal("SEATED")
	assert_str(e[-1]["value"]).is_equal("2")
	assert_str(e[-1]["status"]).is_equal(ShipLog.WARN)
	for id in [Sections.SOLAR_ARRAY, Sections.DORSAL_ARM]:
		_gs.progress.mark(Progress.SEATED_SECTIONS, id)
	EventBus.section_seated.emit(Sections.DORSAL_ARM)
	assert_str(_gs.ship_log.entries[-1]["value"]).is_equal("0")
	assert_str(_gs.ship_log.entries[-1]["status"]).is_equal(ShipLog.INFO)


func test_the_tab_lists_newest_first_and_marks_new() -> void:
	_gs.write_log(ShipLog.SYS, "SR-7 STATUS", "CRITICAL", ShipLog.ERR)
	_gs.write_log(ShipLog.SONAR, "FUEL TANK", "CONTACT")
	var tab := auto_free(ShipLogTab.new()) as ShipLogTab
	add_child(tab)
	tab.refresh()
	var lines := tab.lines()
	assert_int(lines.size()).is_equal(2)
	assert_str(lines[0]).contains("FUEL TANK").contains("CONTACT").ends_with(ShipLogTab.NEW_TAG)
	assert_str(lines[1]).contains("CRITICAL")
	tab.on_hidden()
	tab.refresh()
	assert_str(tab.lines()[0]).not_contains(ShipLogTab.NEW_TAG)


func test_the_cue_waits_until_it_can_show() -> void:
	var cue := auto_free(LogCue.new()) as LogCue
	add_child(cue)
	assert_bool(cue.is_pending()).is_false()
	_gs.write_log(ShipLog.SYS, "X", "Y")
	assert_bool(cue.is_pending()).is_true()
	cue.clear_now()
	assert_bool(cue.is_pending()).is_false()
	assert_str(LogCue.full_text()).starts_with(LogCue.TEXT)
