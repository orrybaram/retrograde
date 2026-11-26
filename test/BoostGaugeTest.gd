extends GdUnitTestSuite

## The boost gauge around the minimap: fuel blocks and the engine bar.


func test_one_block_per_ten_fuel() -> void:
	assert_int(BoostGauge.block_count(150.0)).is_equal(15)
	assert_int(BoostGauge.block_count(250.0)).is_equal(25)
	assert_int(BoostGauge.block_count(155.0)).is_equal(16)


func test_blocks_fill_from_the_bottom() -> void:
	assert_float(BoostGauge.block_fill(112.0, 0)).is_equal(1.0)
	assert_float(BoostGauge.block_fill(112.0, 10)).is_equal(1.0)
	assert_float(BoostGauge.block_fill(112.0, 11)).is_equal_approx(0.2, 0.0001)
	assert_float(BoostGauge.block_fill(112.0, 12)).is_equal(0.0)
	assert_float(BoostGauge.block_fill(0.0, 0)).is_equal(0.0)


func test_engine_idle_cruise_and_boost() -> void:
	assert_float(BoostGauge.engine_output(false, false, 2.667)).is_equal(0.0)
	assert_float(BoostGauge.engine_output(true, false, 2.667)).is_equal(1.0)
	assert_float(BoostGauge.engine_output(true, true, 2.667)).is_equal(2.667)


func test_boost_without_thrust_is_nothing() -> void:
	assert_float(BoostGauge.engine_output(false, true, 2.667)).is_equal(0.0)


func test_boost_sits_under_the_top_of_the_scale() -> void:
	var ship := auto_free(load("res://entities/Ship/Ship.gd").new()) as Ship
	assert_float(ship.boost_power_multiplier).is_less(BoostGauge.ENGINE_SCALE)


func test_fuel_color_steps_toward_rust() -> void:
	assert_object(BoostGauge.fuel_color(150.0, 150.0)).is_equal(Colors.FUEL_FULL)
	assert_object(BoostGauge.fuel_color(75.0, 150.0)).is_equal(Colors.FUEL_HALF)
	assert_object(BoostGauge.fuel_color(30.0, 150.0)).is_equal(Colors.FUEL_QUARTER)
	assert_object(BoostGauge.fuel_color(0.0, 150.0)).is_equal(Colors.FUEL_EMPTY)


func test_blink_only_when_low_and_not_dry() -> void:
	# 0.9s into a 1s period is the dim half
	assert_bool(BoostGauge.blink_dim(100.0, 150.0, 0.9)).is_false()
	assert_bool(BoostGauge.blink_dim(30.0, 150.0, 0.9)).is_true()
	assert_bool(BoostGauge.blink_dim(30.0, 150.0, 0.1)).is_false()
	assert_bool(BoostGauge.blink_dim(0.0, 150.0, 0.9)).is_false()


func test_critical_blinks_faster() -> void:
	# 0.4s: dim half of the 0.5s critical period, lit half of the 1s low period
	assert_bool(BoostGauge.blink_dim(10.0, 150.0, 0.4)).is_true()
	assert_bool(BoostGauge.blink_dim(30.0, 150.0, 0.4)).is_false()
