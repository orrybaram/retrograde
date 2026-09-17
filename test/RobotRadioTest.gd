extends GdUnitTestSuite

## Tests for the robot radio: queue ordering and priority, show-once flags and
## their save round trip, the event triggers, and the message data.

const RADIO_SCRIPT := preload("res://scripts/RobotRadio.gd")
const SAVE_FILE := "user://radio_test_save.cfg"
const Result := RadioQueue.Result
const Priority := RadioConversation.Priority


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))


func _conv(id: StringName, priority: Priority = Priority.HINT, line_count: int = 1, once: bool = false) -> RadioConversation:
	var lines: Array[RadioLine] = []
	for i in line_count:
		lines.append(RadioLine.make("%s line %d" % [id, i]))
	return RadioConversation.make(id, lines, priority, once)


func _radio() -> Node:
	var radio: Node = auto_free(RADIO_SCRIPT.new())
	radio.persist = false
	return radio


# --- RadioQueue ------------------------------------------------------------------

func test_first_push_starts_on_first_line() -> void:
	var q := RadioQueue.new()
	var a := _conv(&"a", Priority.HINT, 2)
	assert_int(q.push(a)).is_equal(Result.STARTED)
	assert_object(q.current).is_same(a)
	assert_object(q.current_line()).is_same(a.lines[0])


func test_equal_priority_waits_in_order() -> void:
	var q := RadioQueue.new()
	q.push(_conv(&"a"))
	assert_int(q.push(_conv(&"b"))).is_equal(Result.QUEUED)
	assert_int(q.push(_conv(&"c"))).is_equal(Result.QUEUED)
	assert_str(str(q.advance().text)).is_equal("b line 0")
	assert_str(str(q.advance().text)).is_equal("c line 0")
	assert_object(q.advance()).is_null()
	assert_bool(q.is_active()).is_false()


func test_lower_priority_does_not_interrupt() -> void:
	var q := RadioQueue.new()
	var warning := _conv(&"warn", Priority.WARNING)
	q.push(warning)
	assert_int(q.push(_conv(&"tip", Priority.CHATTER))).is_equal(Result.QUEUED)
	assert_object(q.current).is_same(warning)


func test_higher_priority_interrupts_and_interrupted_replays_first() -> void:
	var q := RadioQueue.new()
	var tip := _conv(&"tip", Priority.HINT, 3)
	var other_tip := _conv(&"other", Priority.HINT)
	q.push(tip)
	q.push(other_tip)
	q.advance()  # mid-conversation
	var warning := _conv(&"warn", Priority.WARNING)
	assert_int(q.push(warning)).is_equal(Result.INTERRUPTED)
	assert_object(q.current).is_same(warning)
	assert_int(q.line_index).is_equal(0)
	# The interrupted tip resumes from its first line, ahead of the tip queued after it
	assert_object(q.advance()).is_same(tip.lines[0])
	assert_object(q.current).is_same(tip)
	q.advance()
	q.advance()
	assert_object(q.advance()).is_same(other_tip.lines[0])


func test_pending_sorted_by_priority() -> void:
	var q := RadioQueue.new()
	q.push(_conv(&"now", Priority.URGENT))
	q.push(_conv(&"chat", Priority.CHATTER))
	q.push(_conv(&"hint", Priority.HINT))
	q.push(_conv(&"warn", Priority.WARNING))
	assert_str(String(q.advance().text)).is_equal("warn line 0")
	assert_str(String(q.advance().text)).is_equal("hint line 0")
	assert_str(String(q.advance().text)).is_equal("chat line 0")


func test_duplicates_and_empty_are_rejected() -> void:
	var q := RadioQueue.new()
	q.push(_conv(&"a"))
	q.push(_conv(&"b"))
	assert_int(q.push(_conv(&"a"))).is_equal(Result.DUPLICATE)
	assert_int(q.push(_conv(&"b"))).is_equal(Result.DUPLICATE)
	assert_int(q.push(_conv(&"empty", Priority.HINT, 0))).is_equal(Result.REJECTED)
	assert_int(q.push(null)).is_equal(Result.REJECTED)
	assert_int(q.pending_count()).is_equal(1)


func test_duplicate_check_by_id_ignores_blank_ids() -> void:
	var q := RadioQueue.new()
	q.push(_conv(&""))
	assert_int(q.push(_conv(&""))).is_equal(Result.QUEUED)


func test_queue_is_capped() -> void:
	var q := RadioQueue.new()
	q.push(_conv(&"on_air"))
	for i in RadioQueue.MAX_PENDING:
		assert_int(q.push(_conv(StringName("q%d" % i)))).is_equal(Result.QUEUED)
	assert_int(q.push(_conv(&"overflow"))).is_equal(Result.REJECTED)
	# Higher priority still gets through by interrupting
	assert_int(q.push(_conv(&"alarm", Priority.URGENT))).is_equal(Result.INTERRUPTED)


func test_clear_goes_quiet() -> void:
	var q := RadioQueue.new()
	q.push(_conv(&"a", Priority.HINT, 2))
	q.push(_conv(&"b"))
	q.advance()
	q.clear()
	assert_bool(q.is_active()).is_false()
	assert_int(q.pending_count()).is_equal(0)
	assert_int(q.line_index).is_equal(0)


# --- RobotRadio -----------------------------------------------------------------

func test_show_once_plays_only_once() -> void:
	var radio := _radio()
	var tip := _conv(&"tip", Priority.HINT, 1, true)
	assert_int(radio.request(tip)).is_equal(Result.STARTED)
	assert_bool(radio.has_seen(&"tip")).is_true()
	radio.advance()
	assert_int(radio.request(tip)).is_equal(Result.REJECTED)
	assert_bool(radio.is_active()).is_false()


func test_repeatable_messages_play_again() -> void:
	var radio := _radio()
	var chatter := _conv(&"chatter", Priority.CHATTER)
	radio.request(chatter)
	radio.advance()
	assert_int(radio.request(chatter)).is_equal(Result.STARTED)
	assert_bool(radio.has_seen(&"chatter")).is_false()


func test_rejected_duplicate_does_not_mark_seen() -> void:
	var radio := _radio()
	radio.request(_conv(&"x"))
	assert_int(radio.request(_conv(&"x", Priority.HINT, 1, true))).is_equal(Result.DUPLICATE)
	assert_bool(radio.has_seen(&"x")).is_false()


func test_signals_follow_the_lines() -> void:
	var radio := _radio()
	var started: Array[RadioLine] = []
	var ended := [0]
	radio.line_started.connect(func(line: RadioLine, _c: RadioConversation) -> void: started.append(line))
	radio.transmission_ended.connect(func() -> void: ended[0] += 1)
	var a := _conv(&"a", Priority.HINT, 2)
	var b := _conv(&"b")
	radio.request(a)
	radio.request(b)  # queued: no signal yet
	assert_int(started.size()).is_equal(1)
	radio.advance()
	radio.advance()
	assert_array(started).is_equal([a.lines[0], a.lines[1], b.lines[0]])
	assert_int(ended[0]).is_equal(0)
	radio.advance()
	assert_int(ended[0]).is_equal(1)
	radio.advance()  # already quiet: no extra signal
	assert_int(ended[0]).is_equal(1)


func test_seen_flags_round_trip_through_save() -> void:
	ConfigFile.new().save(SAVE_FILE)  # an existing game save
	var radio := _radio()
	radio.persist = true
	radio.save_path = SAVE_FILE
	radio.request(_conv(&"first_tip", Priority.HINT, 1, true))
	radio.request(_conv(&"second_tip", Priority.HINT, 1, true))
	var loaded := Save.load_radio_seen(SAVE_FILE)
	assert_array(Array(loaded)).contains_exactly_in_any_order(["first_tip", "second_tip"])

	var fresh := _radio()
	fresh.load_seen(loaded)
	assert_int(fresh.request(_conv(&"first_tip", Priority.HINT, 1, true))).is_equal(Result.REJECTED)


func test_saving_flags_keeps_other_save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "credits", 42)
	cfg.save(SAVE_FILE)
	Save.save_radio_seen(PackedStringArray(["a"]), SAVE_FILE)
	cfg = ConfigFile.new()
	cfg.load(SAVE_FILE)
	assert_int(cfg.get_value("stats", "credits", 0)).is_equal(42)
	assert_array(Array(Save.load_radio_seen(SAVE_FILE))).is_equal(["a"])


func test_flags_never_create_a_save_file() -> void:
	Save.save_radio_seen(PackedStringArray(["a"]), SAVE_FILE)
	assert_bool(FileAccess.file_exists(SAVE_FILE)).is_false()


func test_missing_save_has_no_flags() -> void:
	assert_int(Save.load_radio_seen("user://no_such_radio_save.cfg").size()).is_equal(0)


func test_reset_forgets_flags_and_silences() -> void:
	var radio := _radio()
	radio.request(_conv(&"tip", Priority.HINT, 1, true))
	radio.reset()
	assert_bool(radio.is_active()).is_false()
	assert_bool(radio.has_seen(&"tip")).is_false()


func test_load_seen_drops_what_was_on_air() -> void:
	var radio := _radio()
	radio.request(_conv(&"a"))
	radio.load_seen(PackedStringArray(["b"]))
	assert_bool(radio.is_active()).is_false()
	assert_bool(radio.has_seen(&"b")).is_true()


# --- Triggers --------------------------------------------------------------------

func test_departure_fires_once_on_undock() -> void:
	var radio := _radio()
	var landed: State = auto_free(LandedState.new())
	var flying: State = auto_free(FlyingState.new())
	radio.on_ship_state_changed(flying, landed)
	assert_bool(radio.is_active()).is_false()
	radio.on_ship_state_changed(landed, flying)
	assert_object(radio.queue.current).is_same(RADIO_SCRIPT.MSG_DEPARTURE)
	radio.silence()
	radio.on_ship_state_changed(landed, flying)
	assert_bool(radio.is_active()).is_false()


func test_low_fuel_fires_below_threshold_and_interrupts_tips() -> void:
	var radio := _radio()
	radio.check_fuel(100.0, 100.0)
	assert_bool(radio.is_active()).is_false()
	radio.request(RADIO_SCRIPT.MSG_SCRAP)
	radio.check_fuel(100.0 * LowFuelEffect.LOW_RATIO, 100.0)
	assert_object(radio.queue.current).is_same(RADIO_SCRIPT.MSG_LOW_FUEL)
	assert_int(radio.queue.pending_count()).is_equal(1)


func test_cargo_full_fires_when_hold_fills() -> void:
	var radio := _radio()
	radio.check_cargo(80.0, 160.0)
	assert_bool(radio.is_active()).is_false()
	radio.check_cargo(160.0, 160.0)
	assert_object(radio.queue.current).is_same(RADIO_SCRIPT.MSG_CARGO_FULL)


func test_scrap_hint_fires_when_harvest_becomes_available() -> void:
	var radio := _radio()
	radio._on_harvest_available_changed(false)
	assert_bool(radio.is_active()).is_false()
	radio._on_harvest_available_changed(true)
	assert_object(radio.queue.current).is_same(RADIO_SCRIPT.MSG_SCRAP)


# --- Data ------------------------------------------------------------------------

func test_bundled_messages_are_valid() -> void:
	for conv: RadioConversation in [RADIO_SCRIPT.MSG_DEPARTURE, RADIO_SCRIPT.MSG_LOW_FUEL,
			RADIO_SCRIPT.MSG_CARGO_FULL, RADIO_SCRIPT.MSG_SCRAP]:
		assert_str(String(conv.id)).is_not_empty()
		assert_bool(conv.once).is_true()
		assert_bool(conv.lines.is_empty()).is_false()
		for line in conv.lines:
			assert_bool(RobotFaces.has_face(line.expression)).override_failure_message("%s: %s" % [conv.id, line.expression]).is_true()
			assert_str(line.display_text()).is_not_empty()
			assert_bool(line.display_text().contains("{key:")).override_failure_message(line.text).is_false()


func test_low_fuel_outranks_tips() -> void:
	assert_int(RADIO_SCRIPT.MSG_LOW_FUEL.priority).is_greater(RADIO_SCRIPT.MSG_SCRAP.priority)


func test_key_tokens_use_the_input_map() -> void:
	var line := RadioLine.make("Hold {key:thrust}, then {key:radio_next}.")
	assert_str(line.display_text()).is_equal("Hold UP, then TAB.")


func test_speaker_defaults_to_the_guide() -> void:
	var line := RadioLine.make("hi")
	assert_str(line.speaker_name()).is_equal(RobotRadio.SPEAKER_NAME)
	line.speaker = "TRADER"
	assert_str(line.speaker_name()).is_equal("TRADER")


func test_read_time_scales_and_clamps() -> void:
	var short := RadioLine.make("Hi").read_time()
	var medium := RadioLine.make("x".repeat(60)).read_time()
	var huge := RadioLine.make("x".repeat(1000)).read_time()
	assert_float(short).is_equal(RadioLine.MIN_READ_TIME)
	assert_float(medium).is_greater(short)
	assert_float(huge).is_equal(RadioLine.MAX_READ_TIME)


func test_beeper_tone_has_expected_length() -> void:
	var wav := RobotBeeper.tone([440.0, 880.0], 0.05)
	var samples := int(0.05 * RobotBeeper.MIX_RATE)
	assert_int(wav.data.size()).is_equal(samples * 2 * 2)
	assert_int(wav.format).is_equal(AudioStreamWAV.FORMAT_16_BITS)
