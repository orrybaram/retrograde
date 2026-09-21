extends GdUnitTestSuite

## Scrap passes for debris until a Sweep ring reaches it: tinted dark, sparkles hidden, off
## the minimap and taking no cut. The ring lights it up for the rest of its spawn.

var _scrap: ScrapNode

func before_test() -> void:
	_scrap = ResourceNodePool.get_instance("Scrap1", self) as ScrapNode
	await get_tree().process_frame

func after_test() -> void:
	if is_instance_valid(_scrap):
		ResourceNodePool.return_instance(_scrap)

func _sparkles() -> CanvasItem:
	return _scrap.get_node("SparkleParticles") as CanvasItem

func test_scrap_starts_hidden_among_the_debris() -> void:
	assert_bool(_scrap.revealed).is_false()
	assert_bool(_scrap.is_in_group("sonar_listeners")).is_true()
	assert_float(_sparkles().modulate.a).is_equal(0.0)
	var poly := _scrap._find_visual_node() as Polygon2D
	var seen := poly.color * _scrap._shape_instance.modulate
	assert_float(seen.r).is_equal_approx(ScrapNode.DORMANT_COLOR.r, 0.01)
	assert_float(seen.g).is_equal_approx(ScrapNode.DORMANT_COLOR.g, 0.01)
	assert_float(seen.b).is_equal_approx(ScrapNode.DORMANT_COLOR.b, 0.01)

func test_hidden_scrap_is_off_the_minimap() -> void:
	var target := ResourceMinimapTarget.new(_scrap)
	assert_bool(target.is_minimap_visible()).is_false()
	_scrap.reveal(false)
	assert_bool(target.is_minimap_visible()).is_true()

func test_a_ring_reaching_it_lights_it_up() -> void:
	_scrap.on_sonar_touched()
	assert_bool(_scrap.revealed).is_true()
	await await_millis(int(ScrapNode.REVEAL_TIME * 1000.0) + 100)
	assert_that(_scrap._shape_instance.modulate).is_equal(Color.WHITE)
	assert_float(_sparkles().modulate.a).is_equal_approx(1.0, 0.001)

func test_found_scrap_sends_one_cream_ring_back() -> void:
	# The pool can hand back a node whose last echo is still fading; count only new ones
	var before := _scrap.get_children().filter(func(c): return c is SonarEcho)
	_scrap.on_sonar_touched()
	var echoes := _scrap.get_children().filter(func(c): return c is SonarEcho and not before.has(c))
	assert_int(echoes.size()).is_equal(1)
	assert_int(echoes[0].rings).is_equal(1)
	assert_that(echoes[0].color).is_equal(Colors.CREAM)

func test_a_hidden_trophy_does_not_breathe_until_found() -> void:
	_scrap.is_trophy = true
	assert_object(_scrap._trophy_pulse_tween).is_null()
	_scrap.reveal(false)
	assert_object(_scrap._trophy_pulse_tween).is_not_null()

func test_a_pinged_ring_reaches_scrap_in_range() -> void:
	var pulse: SonarPulse = auto_free(SonarPulse.new())
	add_child(pulse)
	_scrap.global_position = pulse.global_position + Vector2(100, 0)
	pulse.fire()
	var delay := SonarPulse.time_to_reach(100.0)
	await await_millis(int(delay * 1000.0) + 100)
	assert_bool(_scrap.revealed).is_true()

func test_scrap_goes_dark_again_when_the_pool_reuses_it() -> void:
	_scrap.reveal(false)
	ResourceNodePool.return_instance(_scrap)
	_scrap = ResourceNodePool.get_instance("Scrap1", self) as ScrapNode
	assert_bool(_scrap.revealed).is_false()
	assert_float(_sparkles().modulate.a).is_equal(0.0)

func test_containers_and_derelicts_are_never_hidden() -> void:
	assert_bool(auto_free(ContainerNode.new())._hides_until_pinged()).is_false()
	assert_bool(auto_free(DerelictShip.new())._hides_until_pinged()).is_false()
