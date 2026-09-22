extends GdUnitTestSuite

## SR-7 is dead until both solar wings are home (docs/OPENING.md §2): StationPower, the
## emergency alarms at the cuts, and the limp comm dish.


func _gs() -> GameState:
	return auto_free(GameState.new())


func test_unpowered_until_both_wings_are_home() -> void:
	var gs := _gs()
	assert_bool(StationPower.is_powered(gs)).is_false()
	gs.mark_section_seated(Sections.SOLAR_ARRAY)
	assert_bool(StationPower.is_powered(gs)).is_false()
	gs.mark_section_seated(Sections.FUEL_TANK)
	gs.mark_section_seated(Sections.DORSAL_ARM)
	assert_bool(StationPower.is_powered(gs)).override_failure_message("the other Sections don't carry power").is_false()
	gs.mark_section_seated(Sections.SOLAR_ARRAY_2)
	assert_bool(StationPower.is_powered(gs)).is_true()


func test_no_game_state_is_no_power() -> void:
	assert_bool(StationPower.is_powered(null)).is_false()


func test_the_emergency_lamp_pulses_slowly_and_never_goes_out() -> void:
	assert_float(CutAlarm.lamp_level(0.0)).is_equal_approx(CutAlarm.LAMP_MIN, 0.001)
	assert_float(CutAlarm.lamp_level(CutAlarm.PERIOD * 0.5)).is_equal_approx(1.0, 0.001)
	assert_float(CutAlarm.lamp_level(CutAlarm.PERIOD)).is_equal_approx(CutAlarm.LAMP_MIN, 0.001)
	for i in 20:
		assert_float(CutAlarm.lamp_level(i * 0.37)).is_between(CutAlarm.LAMP_MIN, 1.0)


func test_a_stopped_alarm_throws_no_sparks() -> void:
	var alarm: CutAlarm = auto_free(CutAlarm.new())
	alarm.segments = [[Vector2(0, -10), Vector2(0, 10), Vector2.RIGHT]]
	alarm._burst()
	assert_int(alarm._sparks.size()).is_greater(0)
	alarm.active = false
	assert_int(alarm._sparks.size()).is_equal(0)
	assert_bool(alarm.is_processing()).is_false()


func test_a_limp_dish_hangs_bowl_down() -> void:
	# +x is the bowl: hanging, it points down (+y) and a little out, swaying round that
	for t: float in [0.0, 1.0, 2.5, 4.0]:
		var bowl := Vector2.RIGHT.rotated(CommDish.limp_rotation(t))
		assert_float(bowl.y).is_greater(0.8)
		assert_float(absf(CommDish.limp_rotation(t) - CommDish.LIMP_ANGLE)).is_less_equal(CommDish.SWAY + 0.0001)


func test_lights_come_on_dark_and_wake_one_by_one() -> void:
	var lights: StationLights = auto_free(StationLights.new())
	lights.windows = StationLights.default_windows()
	lights.beacons = StationLights.default_beacons()
	lights.set_lit(true, false)
	assert_bool(lights.is_waking()).is_true()
	# Part way in, some are lit and some are still dark
	lights._process(lights.wake_time() * 0.5)
	var showing := range(lights.windows.size()).filter(func(i: int) -> bool: return lights._showing(i))
	assert_int(showing.size()).is_greater(0)
	assert_int(showing.size()).is_less(lights.windows.size())
	lights._process(lights.wake_time())
	assert_bool(lights.is_waking()).is_false()
	for i in lights.windows.size():
		assert_bool(lights._showing(i)).is_true()
	lights.set_lit(false)
	assert_bool(lights._showing(0)).is_false()


func test_the_lights_wake_outward_from_the_keel_one_at_a_time() -> void:
	var w := StationLights.default_windows()
	var b := StationLights.default_beacons()
	var delays := StationLights.wake_order_delays(w, b)
	var all := w + b
	var sorted := Array(delays)
	sorted.sort()
	for i in range(1, sorted.size()):
		assert_float(sorted[i] - sorted[i - 1]).is_equal_approx(StationLights.WAKE_STEP, 0.0001)
	# The hub (near the keel) catches before the ring pods up top
	var hub := Array(w).find(Vector2(0, -134))
	var pod := Array(w).find(Vector2(-368, -380))
	assert_float(delays[hub]).is_less(delays[pod])


func test_the_dish_pings_once_it_finds_the_sun_under_power() -> void:
	var holder: Node2D = auto_free(Node2D.new())
	add_child(holder)
	var dish := CommDish.new()
	holder.add_child(dish)
	dish.limp = true
	dish._process(0.016)
	dish.limp = false
	assert_bool(dish.is_waking()).is_true()
	for i in 600:
		dish._process(0.05)
		if not dish.is_waking():
			break
	assert_bool(dish.is_waking()).is_false()
	assert_object(dish.get_node_or_null("Ping")).is_not_null()


func test_a_load_brings_the_dish_up_without_a_ping() -> void:
	var holder: Node2D = auto_free(Node2D.new())
	add_child(holder)
	var dish := CommDish.new()
	holder.add_child(dish)
	dish.limp = true
	dish._process(0.016)
	dish.limp = false
	dish.cancel_wake()
	dish._process(0.016)
	assert_bool(dish.is_waking()).is_false()
	assert_object(dish.get_node_or_null("Ping")).is_null()


func test_a_buried_piece_takes_three_tugs() -> void:
	var f: Freight = auto_free(Freight.new())
	f.buried_tugs_left = Freight.BURY_TUGS
	assert_bool(f.is_buried()).is_true()
	assert_bool(f.tug(null)).is_false()
	assert_bool(f.tug(null)).is_false()
	assert_bool(f.tug(null)).is_true()
	assert_bool(f.is_buried()).is_false()


func test_a_buried_piece_saves_how_many_tugs_are_left() -> void:
	var world: Node2D = auto_free(Node2D.new())
	add_child(world)
	var f := Freight.new()
	Sections.apply(f, Sections.SOLAR_ARRAY)
	world.add_child(f)
	f.buried_tugs_left = 2
	var back := Freight.from_row(world, f.to_row())
	assert_int(back.buried_tugs_left).is_equal(2)


func test_the_hanging_wing_sways_but_only_a_little() -> void:
	for t: float in [0.0, 1.0, 2.0, 3.3]:
		assert_float(absf(ArrayNudge.sway_at(t))).is_less_equal(ArrayNudge.SWAY + 0.0001)
	assert_float(ArrayNudge.HANG_ANGLE).is_greater(deg_to_rad(40.0))



func _powered_dish() -> CommDish:
	var holder: Node2D = auto_free(Node2D.new())
	add_child(holder)
	var dish := CommDish.new()
	holder.add_child(dish)
	dish.limp = true
	dish._process(0.016)
	dish.limp = false
	for i in 600:
		dish._process(0.05)
		if not dish.is_waking():
			break
	return dish


func test_the_power_on_ping_is_titan_purple() -> void:
	var dish := _powered_dish()
	var ring: Dictionary = dish.get_node("Ping")._rings[0]
	assert_that(ring["color"]).is_equal(Colors.TITAN)


func test_a_powered_dish_answers_a_sweep_with_the_same_ping() -> void:
	var dish := _powered_dish()
	dish._process(CommDish.PING_COOLDOWN + 0.1)
	var before: int = dish.get_node("Ping").ring_count()
	dish.on_sonar_touched()
	assert_int(dish.get_node("Ping").ring_count()).is_equal(before + 1)
	assert_that(dish.get_node("Ping")._rings.back()["color"]).is_equal(Colors.TITAN)
	# Its own ring reaching it straight away is not another ping
	dish.on_sonar_touched()
	assert_int(dish.get_node("Ping").ring_count()).is_equal(before + 1)


func test_a_dead_dish_answers_nothing() -> void:
	var holder: Node2D = auto_free(Node2D.new())
	add_child(holder)
	var dish := CommDish.new()
	holder.add_child(dish)
	dish.limp = true
	dish._process(0.016)
	dish.on_sonar_touched()
	assert_object(dish.get_node_or_null("Ping")).is_null()
