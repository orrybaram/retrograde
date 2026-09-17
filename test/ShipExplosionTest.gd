extends GdUnitTestSuite

## Tests for the ship death explosion.


func test_shatter_covers_the_polygon() -> void:
	var square := PackedVector2Array([Vector2(-5, -5), Vector2(5, -5), Vector2(5, 5), Vector2(-5, 5)])
	var shards := ShipExplosion.shatter(square, 2)
	assert_int(shards.size()).is_equal(2)
	var area := 0.0
	for shard in shards:
		area += _area(shard)
	assert_float(area).is_equal_approx(100.0, 0.001)


func test_shatter_handles_odd_point_counts() -> void:
	var tri_ish := PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(6, 3), Vector2(2, 6), Vector2(-2, 3)])
	var shards := ShipExplosion.shatter(tri_ish, 2)
	assert_int(shards.size()).is_equal(3)
	var area := 0.0
	for shard in shards:
		area += _area(shard)
	assert_float(area).is_equal_approx(_area(tri_ish), 0.001)


func test_shatter_rejects_degenerate_polygons() -> void:
	assert_int(ShipExplosion.shatter(PackedVector2Array([Vector2.ZERO, Vector2.ONE])).size()).is_equal(0)


func test_hull_polygons_become_debris() -> void:
	var hull := auto_free(Node2D.new()) as Node2D
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-5, -5), Vector2(5, -5), Vector2(5, 5), Vector2(-5, 5)])
	hull.add_child(poly)
	var explosion := auto_free(ShipExplosion.new()) as ShipExplosion
	explosion.start(hull, Vector2.ZERO, null, Vector2.ZERO, 7)
	# 2 hull shards + 10 shrapnel
	assert_int(explosion.find_children("*", "Polygon2D", true, false).size()).is_equal(12)


func test_runs_to_completion_and_fires_every_blast() -> void:
	var explosion := auto_free(ShipExplosion.new()) as ShipExplosion
	explosion.start(null, Vector2(10, 0), null, Vector2.ZERO, 3)
	var steps := 0
	while not explosion.is_finished():
		explosion.advance(1.0 / 30.0)
		steps += 1
	assert_int(steps).is_less(int(ShipExplosion.DURATION * 30.0) + 2)
	for blast in explosion._blasts:
		assert_bool(blast.fired).is_true()
	assert_float(explosion.position.x).is_equal_approx(10.0 * ShipExplosion.DURATION, 1.0)


func test_explosion_restores_camera_offset() -> void:
	var camera := auto_free(Camera2D.new()) as Camera2D
	camera.offset = Vector2(3, 4)
	var explosion := auto_free(ShipExplosion.new()) as ShipExplosion
	explosion.start(null, Vector2.ZERO, camera, Vector2(3, 4), 1)
	explosion.advance(0.1)
	assert_bool(camera.offset != Vector2(3, 4)).is_true()
	while not explosion.is_finished():
		explosion.advance(0.1)
	assert_object(camera.offset).is_equal(Vector2(3, 4))


func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return absf(a) / 2.0
