extends GdUnitTestSuite

## The ship's manual diagnostic (BootChecklist): a header saying the controls are locked,
## FLIGHT first, later sections unfolding when
## opened, each row stamping [ OK ] on first use once it has typed, a finished section
## clearing a moment later, and DIAGNOSTIC ... PASS once all five have cleared. Keys are named by a fixed table so the
## rows read the same whatever Controls is bound to.

const KEYS := {
	&"thrust": "UP", &"reverse_thrust": "DOWN", &"turn_left": "LEFT", &"turn_right": "RIGHT",
	&"action": "SPACE", &"strafe_left": "Q", &"strafe_right": "E",
}


func _checklist() -> BootChecklist:
	return BootChecklist.new(func(action: StringName) -> String: return KEYS.get(action, "?"))


## Long enough for everything open to type out and stamp.
func _settle(c: BootChecklist, seconds := 6.0) -> void:
	var t := 0.0
	while t < seconds:
		c.tick(0.05)
		t += 0.05


## A status field as it reads: name, dots, value.
func _field(name: String, value: String) -> String:
	var s := ""
	for seg in BootChecklist.field(name, value, Color.WHITE):
		s += seg[0]
	return s


func _line(c: BootChecklist, starts: String) -> String:
	for line in c.plain().split("\n"):
		if line.begins_with(starts):
			return line
	return ""


func test_flight_rows_list_each_control_with_its_key() -> void:
	var c := _checklist()
	c.open(BootChecklist.FLIGHT)
	_settle(c)
	var text := c.plain()
	assert_str(text).contains("PROPULSION")
	assert_str(_line(c, "THRUST")).is_equal("THRUST ....... [UP]          [ -- ]")
	assert_str(_line(c, "YAW")).contains("[LEFT][RIGHT]")
	assert_str(text).not_contains("SONAR")


func test_rows_type_in_one_at_a_time() -> void:
	var c := _checklist()
	c.open(BootChecklist.FLIGHT)
	c.tick(0.1)
	assert_str(c.plain()).is_equal(BootChecklist.TITLE.substr(0, 5) + BootChecklist.CURSOR)


func test_it_opens_by_saying_the_controls_are_locked() -> void:
	var c := _checklist()
	c.open(BootChecklist.FLIGHT)
	_settle(c)
	var lines := c.plain().split("\n")
	assert_str(lines[0]).is_equal(BootChecklist.TITLE)
	assert_str(lines[1]).is_equal(_field(BootChecklist.AUTHORITY, BootChecklist.HELD_BY))
	assert_str(lines[3]).is_equal("PROPULSION")


func test_a_section_is_live_once_its_heading_has_typed() -> void:
	var c := _checklist()
	c.open(BootChecklist.FLIGHT)
	assert_bool(c.is_live(BootChecklist.FLIGHT)).is_false()
	assert_bool(c.is_live(BootChecklist.SONAR)).is_false()
	_settle(c)
	assert_bool(c.is_live(BootChecklist.FLIGHT)).is_true()


func test_a_used_control_stamps_ok() -> void:
	var c := _checklist()
	c.open(BootChecklist.FLIGHT)
	_settle(c)
	c.use(BootChecklist.THRUST)
	c.tick(0.05)
	assert_bool(c.is_done("thrust")).is_true()
	assert_str(_line(c, "THRUST")).ends_with(BootChecklist.STAMP_OK)
	assert_str(_line(c, "REVERSE")).ends_with(BootChecklist.STAMP_WAIT)


func test_turn_needs_both_ways() -> void:
	var c := _checklist()
	c.open(BootChecklist.FLIGHT)
	_settle(c)
	c.use(BootChecklist.TURN_LEFT)
	c.tick(0.05)
	assert_bool(c.is_done("turn")).is_false()
	c.use(BootChecklist.TURN_RIGHT)
	c.tick(0.05)
	assert_bool(c.is_done("turn")).is_true()


func test_a_row_waits_until_typed_before_it_stamps() -> void:
	var c := _checklist()
	c.use(BootChecklist.THRUST)
	c.open(BootChecklist.FLIGHT)
	c.tick(0.05)
	assert_bool(c.is_done("thrust")).is_false()
	_settle(c)
	assert_bool(c.is_done("thrust")).is_true()


func test_strafe_needs_both_sides() -> void:
	var c := _checklist()
	c.open(BootChecklist.LATERAL)
	c.use(BootChecklist.SEATED)
	_settle(c)
	c.use(BootChecklist.STRAFE_LEFT)
	c.tick(0.05)
	assert_bool(c.is_done("strafe")).is_false()
	c.use(BootChecklist.STRAFE_RIGHT)
	c.tick(0.05)
	assert_bool(c.is_done("strafe")).is_true()


func test_sections_unfold_in_the_order_they_open() -> void:
	var c := _checklist()
	c.open(BootChecklist.FLIGHT)
	c.open(BootChecklist.MAGNET)
	c.open(BootChecklist.MAGNET)
	_settle(c, 5.0)
	var text := c.plain()
	assert_int(text.find("CLAMP")).is_greater(text.find("PROPULSION"))
	assert_int(text.count("CLAMP")).is_equal(1)


func test_clamp_stamp_fills_with_the_magnet() -> void:
	var c := _checklist()
	c.open(BootChecklist.MAGNET)
	_settle(c)
	c.hold_progress = 0.5
	assert_str(_line(c, "ENGAGE")).contains("HOLD [SPACE]")
	assert_str(_line(c, "ENGAGE")).ends_with("[██··]")


func test_contact_lands_under_sweep_even_when_it_came_first() -> void:
	var c := _checklist()
	c.contact()
	c.open(BootChecklist.SONAR)
	_settle(c)
	var lines := c.plain().split("\n")
	var sweep := -1
	for i in lines.size():
		if lines[i].begins_with("SWEEP"):
			sweep = i
	assert_str(lines[sweep + 1]).is_equal(_field(BootChecklist.CONTACT[0], BootChecklist.CONTACT[1]))


func test_complete_once_every_section_is_open_and_done() -> void:
	var c := _checklist()
	for mark in [BootChecklist.THRUST, BootChecklist.REVERSE, BootChecklist.TURN_LEFT,
			BootChecklist.TURN_RIGHT, BootChecklist.SWEEP, BootChecklist.CLAMP, BootChecklist.STRAFE_LEFT,
			BootChecklist.STRAFE_RIGHT,
			BootChecklist.RELEASE]:
		c.use(mark)
	c.open(BootChecklist.FLIGHT)
	c.open(BootChecklist.SONAR)
	c.open(BootChecklist.MAGNET)
	c.open(BootChecklist.LATERAL)
	_settle(c, 6.0)
	assert_bool(c.is_complete()).is_false()
	c.open(BootChecklist.LET_GO)
	_settle(c, 9.0)
	assert_bool(c.is_complete()).is_true()
	var lines := c.plain().trim_suffix(BootChecklist.CURSOR).split("\n")
	assert_str(lines[0]).is_equal(BootChecklist.TITLE)
	assert_int(lines.size()).is_equal(1 + BootChecklist.ORDER.size() + 3)
	assert_str(lines[-2]).is_equal(_field(BootChecklist.RESULT[0], BootChecklist.RESULT[1]))
	assert_str(lines[-1]).is_equal(_field(BootChecklist.AUTHORITY, BootChecklist.HANDED_TO))
	assert_str(c.plain()).not_contains(BootChecklist.HELD_BY)
	assert_bool(c.is_finished()).is_false()
	_settle(c, BootChecklist.COMPLETE_HOLD + 0.5)
	assert_bool(c.is_finished()).is_true()


func test_a_finished_section_clears_and_the_rest_close_up() -> void:
	var c := _checklist()
	c.open(BootChecklist.FLIGHT)
	c.open(BootChecklist.SONAR)
	_settle(c)
	for mark in [BootChecklist.THRUST, BootChecklist.REVERSE, BootChecklist.TURN_LEFT, BootChecklist.TURN_RIGHT]:
		c.use(mark)
	c.tick(0.05)
	assert_str(c.plain()).contains("PROPULSION")
	_settle(c, BootChecklist.CLEAR_DELAY + 1.0)
	assert_bool(c.is_cleared(BootChecklist.FLIGHT)).is_true()
	assert_str(c.plain()).not_contains("THRUST")
	var lines := c.plain().split("\n")
	assert_str(lines[0]).is_equal(BootChecklist.TITLE)
	assert_str(lines[2]).is_equal(_field("PROPULSION", BootChecklist.STAMP_OK))
	assert_str(lines[4]).is_equal("SONAR")
	assert_bool(c.is_complete()).is_false()


func test_release_is_a_hold_passed_by_letting_go_or_seating() -> void:
	var c := _checklist()
	c.open(BootChecklist.LET_GO)
	_settle(c)
	c.hold_progress = 0.25
	assert_str(_line(c, "RELEASE ")).contains("HOLD [SPACE]")
	assert_str(_line(c, "RELEASE ")).ends_with("[█···]")
	c.use(BootChecklist.SEATED)
	c.tick(0.05)
	assert_bool(c.is_done("release")).is_true()


func test_passes_list_in_the_order_they_clear() -> void:
	var c := _checklist()
	c.open(BootChecklist.FLIGHT)
	c.open(BootChecklist.SONAR)
	c.open(BootChecklist.MAGNET)
	_settle(c)
	c.use(BootChecklist.CLAMP)
	_settle(c)
	c.use(BootChecklist.SWEEP)
	_settle(c)
	var lines := c.plain().split("\n")
	assert_str(lines[2]).is_equal(_field("CLAMP", BootChecklist.STAMP_OK))
	assert_str(lines[3]).is_equal(_field("SONAR", BootChecklist.STAMP_OK))
	assert_str(lines[5]).is_equal("PROPULSION")


func test_who_holds_the_controls_is_small_and_dim() -> void:
	var c := _checklist()
	_settle(c)
	var bb := c.render()
	assert_str(bb).contains("[font_size=%d]" % BootChecklist.SMALL_SIZE)
	assert_str(bb).not_contains("[color=#%s]%s" % [Colors.hex(Colors.PRIMARY), BootChecklist.AUTHORITY])


func test_keys_are_escaped_for_bbcode() -> void:
	var c := _checklist()
	c.open(BootChecklist.FLIGHT)
	_settle(c)
	assert_str(c.render()).contains("[lb]UP[rb]")
