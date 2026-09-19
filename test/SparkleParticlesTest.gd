extends GdUnitTestSuite

## The harvest beam's throwaway nodes - the arc fragments, the arc root that holds them,
## the pop burst - are all animated or reaped by a tween. Every one of those tweens must
## belong to the node it touches, so that freeing the node (a harvest ending, a scrap
## running out, the scene tearing down) kills the tween with it. A tween that outlives
## its node keeps calling back holding a freed one, which Godot reports as
## "Lambda capture at index 0 was freed" - a printed error that tools/smoke.sh fails on.


func _sparkle() -> SparkleParticles:
	var sparkle: SparkleParticles = auto_free(SparkleParticles.new())
	add_child(sparkle)
	# The test drives spawning by hand; _process would keep adding fragments mid-assert.
	sparkle.set_process(false)
	return sparkle


func _target() -> Node2D:
	var target: Node2D = auto_free(Node2D.new())
	add_child(target)
	target.global_position = Vector2(140, -60)
	return target


## The one tween `action` started, so an unrelated tween elsewhere can't stand in for it.
func _tween_started_by(action: Callable) -> Tween:
	var before := get_tree().get_processed_tweens()
	action.call()
	var started: Array[Tween] = []
	for tween in get_tree().get_processed_tweens():
		if not before.has(tween):
			started.append(tween)
	assert_int(started.size()).is_equal(1)
	assert_bool(started[0].is_valid()).is_true()
	return started[0]


func test_arc_fragment_tween_dies_with_the_fragment() -> void:
	var sparkle := _sparkle()
	sparkle.set_harvesting(_target())
	var tween := _tween_started_by(sparkle._spawn_arc_particle)

	var root := sparkle.get_node("ArcParticles")
	assert_int(root.get_child_count()).is_equal(1)

	# The harvest ends and the fragment is reaped while it is still in flight.
	root.get_child(0).free()
	await get_tree().process_frame
	assert_bool(tween.is_valid()).is_false()


func test_arc_root_reaper_dies_with_the_root() -> void:
	var sparkle := _sparkle()
	sparkle.set_harvesting(_target())
	var root := sparkle.get_node("ArcParticles")
	var reap := _tween_started_by(sparkle.set_idle)

	# Teardown frees the root before the linger is up.
	root.free()
	await get_tree().process_frame
	assert_bool(reap.is_valid()).is_false()


func test_pop_burst_reaper_dies_with_the_burst() -> void:
	var sparkle := _sparkle()
	var reap := _tween_started_by(sparkle.pop)

	var burst := sparkle.get_child(sparkle.get_child_count() - 1)
	burst.free()
	await get_tree().process_frame
	assert_bool(reap.is_valid()).is_false()
