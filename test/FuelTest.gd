extends GdUnitTestSuite

## Tests for fuel capacity tuning and low-fuel warning thresholds.


func test_level_ok_above_quarter() -> void:
	assert_int(Drive.level_for(200.0, 200.0)).is_equal(Drive.Level.OK)
	assert_int(Drive.level_for(51.0, 200.0)).is_equal(Drive.Level.OK)


func test_level_low_at_quarter() -> void:
	assert_int(Drive.level_for(50.0, 200.0)).is_equal(Drive.Level.LOW)
	assert_int(Drive.level_for(21.0, 200.0)).is_equal(Drive.Level.LOW)


func test_level_critical_at_tenth_and_empty() -> void:
	assert_int(Drive.level_for(20.0, 200.0)).is_equal(Drive.Level.CRITICAL)
	assert_int(Drive.level_for(0.0, 200.0)).is_equal(Drive.Level.CRITICAL)
	assert_int(Drive.level_for(5.0, 0.0)).is_equal(Drive.Level.CRITICAL)


func test_base_tank_is_150() -> void:
	var ship := auto_free(load("res://entities/Ship/Ship.gd").new()) as Ship
	assert_float(ship.drive.max_fuel).is_equal(150.0)
	assert_float(Drive.CAPACITY).is_equal(150.0)
