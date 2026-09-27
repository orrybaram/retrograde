extends GdUnitTestSuite

## Tests for the docking Deposit sequence: gems leave the hold one by one and are
## added to the Stores when they reach the port.


func before_test() -> void:
	InventoryManager.clear_inventory()


func after_test() -> void:
	InventoryManager.clear_inventory()


func _game_state() -> GameState:
	var gs: GameState = auto_free(GameState.new())
	gs.stores = 0
	return gs


func test_launch_order_is_one_id_per_gem_cheapest_first() -> void:
	var ids := HoldDeposit.launch_order({"artifact": 1, "shard": 2, "crystal": 1, "junk": 4})
	assert_array(ids).contains_exactly(["shard", "shard", "crystal", "artifact"])


func test_interval_spreads_small_holds_and_caps_big_ones() -> void:
	assert_float(HoldDeposit.interval_for(1)).is_equal(HoldDeposit.MAX_INTERVAL)
	assert_float(HoldDeposit.interval_for(1000)).is_equal(HoldDeposit.MIN_INTERVAL)
	assert_float(HoldDeposit.interval_for(40)).is_equal_approx(HoldDeposit.TOTAL_TIME / 40.0, 0.0001)


func test_empty_hold_starts_nothing() -> void:
	var port: Node2D = auto_free(Node2D.new())
	assert_object(HoldDeposit.begin(port, null, _game_state())).is_null()


func test_hold_drains_while_stores_count_up() -> void:
	var gs := _game_state()
	var port: Node2D = auto_free(Node2D.new())
	add_child(port)
	InventoryManager.add_item("gem", 3)
	InventoryManager.add_item("crystal", 1)
	var expected := InventoryManager.get_total_value()
	var deposit := HoldDeposit.begin(port, null, gs)

	deposit._process(HoldDeposit.START_DELAY - 0.01)
	deposit._process(0.02)
	assert_int(InventoryManager.get_quantity("gem")).is_equal(2)
	assert_int(gs.stores).is_equal(0)

	var totals := []
	deposit.finished.connect(func(total): totals.append(total))
	for i in 200:
		if totals.size() > 0:
			break
		deposit._process(0.05)
	assert_array(totals).contains_exactly([expected])
	assert_int(gs.stores).is_equal(expected)
	assert_int(InventoryManager.get_total_value()).is_equal(0)
	assert_int(HoldDeposit.running).is_equal(0)


func test_finish_banks_everything_immediately() -> void:
	var gs := _game_state()
	var port: Node2D = auto_free(Node2D.new())
	add_child(port)
	InventoryManager.add_item("shard", 5)
	InventoryManager.add_item("artifact", 1)
	var expected := InventoryManager.get_total_value()
	var deposit := HoldDeposit.begin(port, null, gs)
	deposit._process(HoldDeposit.START_DELAY + 0.2)  # some gems in flight
	deposit.finish()
	assert_int(gs.stores).is_equal(expected)
	assert_int(InventoryManager.get_total_value()).is_equal(0)
	assert_int(HoldDeposit.running).is_equal(0)
