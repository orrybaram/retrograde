extends GdUnitTestSuite

## Tests for fuel capacity tuning and low-fuel warning thresholds.


func test_level_ok_above_quarter() -> void:
	assert_int(LowFuelEffect.level_for(200.0, 200.0)).is_equal(LowFuelEffect.Level.OK)
	assert_int(LowFuelEffect.level_for(51.0, 200.0)).is_equal(LowFuelEffect.Level.OK)


func test_level_low_at_quarter() -> void:
	assert_int(LowFuelEffect.level_for(50.0, 200.0)).is_equal(LowFuelEffect.Level.LOW)
	assert_int(LowFuelEffect.level_for(21.0, 200.0)).is_equal(LowFuelEffect.Level.LOW)


func test_level_critical_at_tenth_and_empty() -> void:
	assert_int(LowFuelEffect.level_for(20.0, 200.0)).is_equal(LowFuelEffect.Level.CRITICAL)
	assert_int(LowFuelEffect.level_for(0.0, 200.0)).is_equal(LowFuelEffect.Level.CRITICAL)
	assert_int(LowFuelEffect.level_for(5.0, 0.0)).is_equal(LowFuelEffect.Level.CRITICAL)


func test_base_tank_is_150() -> void:
	var ship := auto_free(load("res://entities/Ship/Ship.gd").new()) as Ship
	assert_float(ship.max_fuel).is_equal(150.0)
	assert_float(ship.base_max_fuel).is_equal(150.0)


func test_fuel_tank_upgrades_scale_with_base() -> void:
	var values := []
	for i in [1, 2, 3]:
		var item := load("res://entities/Upgrades/items/FuelTank_%d.tres" % i) as UpgradeItem
		values.append(item.effect_value)
	assert_array(values).is_equal([100.0, 150.0, 250.0])
