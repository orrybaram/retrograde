extends GdUnitTestSuite

## The name of what a Sweep read blooms over it in the world, then fades (ui/ReadoutEcho.gd).

var _echo: ReadoutEcho

func before_test() -> void:
	_echo = auto_free(ReadoutEcho.new()) as ReadoutEcho
	add_child(_echo)

func _readout(title: String, heading := "MOUNT") -> SweepReadout:
	var owner_node := auto_free(Node2D.new()) as Node2D
	add_child(owner_node)
	var r := SweepReadout.new()
	r.key = "echo_" + title
	r.heading = heading
	r.title = title
	owner_node.add_child(r)
	return r


func test_the_title_types_out_over_the_thing() -> void:
	_echo.show_read(_readout("FUEL TANK"), 1, [])
	_echo._process(0.05)
	assert_str(_echo.lines()[0]).is_not_empty()
	assert_str(_echo.lines()[0]).is_not_equal("FUEL TANK")
	_echo._process(1.0)
	assert_str(_echo.lines()[0]).is_equal("FUEL TANK")


func test_a_thing_with_no_title_blooms_its_heading() -> void:
	_echo.show_read(_readout("", "GATE"), 1, [])
	_echo._process(1.0)
	assert_str(_echo.lines()[0]).is_equal("GATE")


func test_it_holds_then_fades() -> void:
	_echo.show_read(_readout("FUEL TANK"), 1, [])
	_echo._process(1.0)
	_echo._process(ReadoutEcho.HOLD - 0.5)
	assert_int(_echo.lines().size()).is_equal(1)
	_echo._process(0.5 + ReadoutEcho.FADE_TIME)
	assert_int(_echo.lines().size()).is_equal(0)


func test_reading_it_again_blooms_it_again_not_twice() -> void:
	var r := _readout("FUEL TANK")
	_echo.show_read(r, 1, [])
	_echo._process(2.0)
	_echo.show_read(r, 2, [])
	assert_int(_echo.lines().size()).is_equal(1)
	_echo._process(ReadoutEcho.HOLD)
	assert_int(_echo.lines().size()).override_failure_message("its clock started over").is_equal(1)


func test_something_of_the_titans_blooms_as_noise_in_its_purple() -> void:
	var r := _readout("", "GATE")
	r.undecipherable = true
	_echo.show_read(r, 1, [])
	_echo._process(1.0)
	assert_str(_echo.lines()[0]).is_not_equal("GATE")
	assert_int(_echo.lines()[0].length()).is_equal(4)
	var label := _echo._echoes[0].label as Label
	assert_object(label.get_theme_color("font_color")).is_equal(Colors.TITAN)


func test_a_thing_gone_takes_its_echo() -> void:
	var r := _readout("FUEL TANK")
	_echo.show_read(r, 1, [])
	r.get_parent().free()
	_echo._process(0.1)
	assert_int(_echo.lines().size()).is_equal(0)


func test_it_hides_behind_a_hud_panel() -> void:
	var r := _readout("FUEL TANK")
	var panel := auto_free(Control.new()) as Control
	add_child(panel)
	panel.position = Vector2(-5000, -5000)
	panel.size = Vector2(10000, 10000)
	_echo.blockers = [panel]
	_echo.show_read(r, 1, [])
	_echo._process(0.5)
	assert_bool(_echo._echoes[0].label.visible).is_false()
	panel.visible = false
	_echo._process(0.1)
	assert_bool(_echo._echoes[0].label.visible).is_true()
