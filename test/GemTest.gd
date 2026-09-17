extends GdUnitTestSuite

## Tests for loose gems, the ship's magnet, and cashing in the hold.


func before_test() -> void:
	InventoryManager.clear_inventory()


func after_test() -> void:
	InventoryManager.clear_inventory()
	Gem.clear_all()


func test_burst_speed_decays_to_drift() -> void:
	var drift := Vector2(50, 0)
	var v := Vector2(150, 80)
	for i in 300:
		v = Gem.damp(v, drift, 1.0 / 60.0)
	assert_vector(v).is_equal_approx(drift, Vector2(0.5, 0.5))


func test_pull_is_stronger_up_close_and_zero_outside() -> void:
	assert_float(GemMagnet.pull_speed(5.0)).is_greater(GemMagnet.pull_speed(40.0))
	assert_float(GemMagnet.pull_speed(GemMagnet.RADIUS + 1.0)).is_equal(0.0)
	assert_float(GemMagnet.PICKUP_RADIUS).is_less(GemMagnet.RADIUS)


func test_full_hold_rejects_big_gems_before_small_ones() -> void:
	InventoryManager.add_item("shard", 9)
	assert_bool(GemMagnet.fits("shard", 10.0)).is_true()
	assert_bool(GemMagnet.fits("crystal", 10.0)).is_false()
	InventoryManager.add_item("shard", 1)
	assert_bool(GemMagnet.fits("shard", 10.0)).is_false()


func test_gems_take_their_size_in_hold_space() -> void:
	InventoryManager.add_item("artifact", 2)
	InventoryManager.add_item("shard", 1)
	assert_float(InventoryManager.get_total_weight()).is_equal(7.0)


func test_collect_adds_to_hold_and_removes_gem() -> void:
	var world := auto_free(Node2D.new()) as Node2D
	add_child(world)
	var gems := Gem.burst(world, Vector2.ZERO, Vector2.ZERO, ["gem", "crystal"] as Array[String], false, RandomNumberGenerator.new())
	assert_int(Gem.active.size()).is_equal(2)
	gems[0].collect()
	assert_int(InventoryManager.get_quantity("gem")).is_equal(1)
	assert_int(Gem.active.size()).is_equal(1)


func test_active_gems_are_capped() -> void:
	var world := auto_free(Node2D.new()) as Node2D
	add_child(world)
	for i in Gem.MAX_ACTIVE + 5:
		Gem.spawn(world, "shard", Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	assert_int(Gem.active.size()).is_equal(Gem.MAX_ACTIVE)


func test_cash_in_empties_hold_and_returns_value() -> void:
	InventoryManager.add_item("gem", 3)
	InventoryManager.add_item("crystal", 1)
	var expected := 3 * GemData.value_of("gem") + GemData.value_of("crystal")
	assert_int(InventoryManager.cash_in()).is_equal(expected)
	assert_int(InventoryManager.get_total_value()).is_equal(0)
	assert_dict(InventoryManager.get_all_items()).is_empty()
