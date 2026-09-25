extends GdUnitTestSuite

## SR-7's dock arm (docs/OPENING.md §3, §5): run in until every piece of the station is
## home, so a new game has no dock; out on the core's battery once it is whole.

var _world: Node2D
var _gs: GameState
var _station: SpaceStation

func before_test() -> void:
	_world = auto_free(Node2D.new()) as Node2D
	add_child(_world)
	_gs = GameState.new()
	_world.add_child(_gs)
	_station = load("res://entities/structures/SpaceStation.tscn").instantiate() as SpaceStation
	_world.add_child(_station)
	await get_tree().process_frame

func after_test() -> void:
	Freight.clear_all(get_tree())
	NavSystem.track_home()

func _arm() -> DockArm:
	return _station.get_node("DockArm") as DockArm

func _whole() -> void:
	for id in GameState.station_pieces():
		_gs.mark_section_seated(id)


func test_out_only_when_whole_or_running() -> void:
	assert_bool(DockArm.should_be_out(null)).is_false()
	assert_bool(DockArm.should_be_out(_gs)).is_false()
	for id in Sections.DATA.keys():
		_gs.mark_section_seated(id)
	assert_bool(DockArm.should_be_out(_gs)).override_failure_message("the hanging wing counts too").is_false()
	_gs.mark_section_seated(Sections.SOLAR_ARRAY_2)
	assert_bool(DockArm.should_be_out(_gs)).is_true()


func test_a_running_core_means_the_arm_is_out() -> void:
	_gs.core_started = true
	assert_bool(DockArm.should_be_out(_gs)).is_true()


func test_a_new_station_has_its_arm_in_and_no_dock() -> void:
	var arm := _arm()
	var port := arm.get_port()
	assert_bool(arm.out).is_false()
	assert_bool(port.deployed).is_false()
	assert_bool(port.accepts_docking()).is_false()
	assert_float(arm.get_node("Slide").position.x).is_equal(DockArm.STOWED_X)


func test_stowed_the_whole_arm_is_behind_the_track() -> void:
	# The mask's inner edge is where the boom leaves the hull: stowed, nothing on the slide
	# may reach past it, or it would draw over the station.
	var arm := _arm()
	var edge := Freight.bounds(arm.polygon).position.x
	var boom := Freight.bounds((arm.get_node("Slide/RefuelBoom") as Polygon2D).polygon)
	assert_float(boom.end.x + DockArm.STOWED_X).is_less(edge)
	assert_float(arm.get_port().position.x + DockArm.STOWED_X + 10.0).is_less(edge)


func test_stowed_nothing_on_it_collides() -> void:
	await get_tree().physics_frame
	for shape in _arm().get_node("Slide").find_children("*", "CollisionShape2D", true, false):
		assert_bool(shape.disabled).is_true()
	for shape in _arm().get_node("Slide").find_children("*", "CollisionPolygon2D", true, false):
		assert_bool(shape.disabled).is_true()


func test_a_load_into_a_whole_station_snaps_it_out() -> void:
	_whole()
	var arm := _arm()
	arm.refresh()
	await get_tree().physics_frame
	assert_bool(arm.out).is_true()
	assert_bool(arm.get_port().accepts_docking()).is_true()
	assert_float(arm.get_node("Slide").position.x).is_equal(0.0)
	for shape in arm.get_node("Slide").find_children("*", "CollisionShape2D", true, false):
		assert_bool(shape.disabled).is_false()


func test_the_last_piece_runs_it_out_rather_than_snapping_it() -> void:
	var arm := _arm()
	_whole()
	arm._on_section_seated(Sections.SOLAR_ARRAY_2)
	assert_bool(arm.is_extending()).is_true()
	assert_bool(arm.out).override_failure_message("it runs out while the player watches").is_false()
	assert_bool(arm.get_port().accepts_docking()).override_failure_message("no dock until it locks").is_false()


func test_the_station_no_longer_carries_the_boom_in_its_own_collision() -> void:
	# The boom collides from the arm, so it can come and go with it
	var hull := _station.get_node("CollisionShape2D") as CollisionPolygon2D
	assert_bool(Geometry2D.is_point_in_polygon(Vector2(300, 100), hull.polygon)).is_false()
