extends GdUnitTestSuite

## Tests for abandoned ships: salvage shares, grade losses, save round trip.

const PERFECT := HarvestTiming.Grade.PERFECT
const LATE := HarvestTiming.Grade.LATE


func after_test() -> void:
	InventoryManager.clear_inventory()
	DerelictShip.clear_all(get_tree())


func _gems(n: int) -> Array[String]:
	var ids: Array[String] = []
	for i in n:
		ids.append(["shard", "gem", "crystal"][i % 3])
	return ids


func test_all_perfect_salvage_recovers_the_whole_hold() -> void:
	var loot := _gems(23)
	var rng := RandomNumberGenerator.new()
	var recovered: Array[String] = []
	for hits_after in [4, 3, 2, 1, 0]:
		recovered.append_array(DerelictShip.take_share(loot, hits_after, PERFECT, rng))
	assert_int(recovered.size()).is_equal(23)
	assert_array(loot).is_empty()
	for id in ["shard", "gem", "crystal"]:
		assert_int(recovered.count(id)).is_equal(_gems(23).count(id))


func test_final_hit_adds_hull_scrap_on_top_of_the_hold() -> void:
	var world := auto_free(Node2D.new()) as Node2D
	add_child(world)
	var d := DerelictShip.spawn(world, null, _gems(4), Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, 1)
	d.hits_left = 0
	var drops := d.drops_for_hit(PERFECT, true)
	assert_int(drops.size()).is_greater_equal(4 + GemData.BREAK_MIN + GemData.PERFECT_BREAK_BONUS)
	assert_array(d.loot).is_empty()


func test_shares_are_even_across_hits() -> void:
	var loot := _gems(20)
	var got := DerelictShip.take_share(loot, 4, PERFECT, RandomNumberGenerator.new())
	assert_int(got.size()).is_equal(4)
	assert_int(loot.size()).is_equal(16)


func test_botched_hits_lose_part_of_their_share() -> void:
	var loot := _gems(20)
	var got := DerelictShip.take_share(loot, 4, LATE, RandomNumberGenerator.new())
	assert_int(got.size()).is_equal(2)
	assert_int(loot.size()).is_equal(16)  # the lost half is gone for good


func test_empty_hold_leaves_a_bare_hull_that_salvages_like_scrap() -> void:
	var world := auto_free(Node2D.new()) as Node2D
	add_child(world)
	var empty: Array[String] = []
	var d := DerelictShip.spawn(world, null, empty, Vector2.ZERO, Vector2.ZERO, 0.0, 0.0, ScrapNode.NORMAL_HITS)
	assert_bool(d.hull_only).is_true()
	assert_int(d.max_hits()).is_equal(ScrapNode.NORMAL_HITS)
	assert_int(d.hits_left).is_equal(ScrapNode.NORMAL_HITS)
	var drops := d.drops_for_hit(PERFECT, true)
	assert_int(drops.size()).is_greater_equal(GemData.BREAK_MIN + GemData.PERFECT_BREAK_BONUS)

	var rows := DerelictShip.snapshot_all(get_tree())
	assert_bool(rows[0]["hull_only"]).is_true()
	d.free()
	DerelictShip.restore_all(world, null, rows)
	var restored := get_tree().get_nodes_in_group("derelicts")
	assert_int(restored.size()).is_equal(1)
	assert_bool((restored[0] as DerelictShip).hull_only).is_true()


func test_derelict_drifts_to_a_slow_tumble_and_round_trips() -> void:
	var world := auto_free(Node2D.new()) as Node2D
	add_child(world)
	var hull := Node2D.new()
	var poly := Polygon2D.new()
	poly.name = "Polygon2D"
	poly.polygon = PackedVector2Array([Vector2(10, 0), Vector2(-8, 6), Vector2(-8, -6)])
	hull.add_child(poly)
	world.add_child(hull)

	var d := DerelictShip.spawn(world, hull, _gems(9), Vector2(100, 50), Vector2(300, 0), 0.5, 0.1, 5)
	assert_int(d.max_hits()).is_equal(5)
	assert_bool(d.is_trophy).is_false()
	assert_vector(d.get_orbital_velocity()).is_equal(Vector2(300, 0))
	for i in 600:
		d._physics_process(1.0 / 30.0)
	assert_float(d.drift.length()).is_less_equal(DerelictShip.RESIDUAL_DRIFT + 1.0)
	assert_int(d.get_node("DerelictVisual").get_child_count()).is_equal(1)

	d.hits_left = 3
	var rows := DerelictShip.snapshot_all(get_tree())
	assert_int(rows.size()).is_equal(1)
	d.free()
	DerelictShip.restore_all(world, hull, rows)
	var restored := get_tree().get_nodes_in_group("derelicts")
	assert_int(restored.size()).is_equal(1)
	var r := restored[0] as DerelictShip
	assert_int(r.hits_left).is_equal(3)
	assert_int(r.loot.size()).is_equal(9)
	assert_vector(r.global_position).is_equal_approx(rows[0]["x"] * Vector2.RIGHT + rows[0]["y"] * Vector2.DOWN, Vector2(0.01, 0.01))
