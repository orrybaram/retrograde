extends GdUnitTestSuite

## A Sweep lights what it reaches of a reactive outline, and a discoverable one answers with
## the found trace: the empty Mount's cut edges first. Rings are stepped by hand.

const FRAME := 1.0 / 60.0

var _world: Node2D
var _station: SpaceStation

func before_test() -> void:
	_world = auto_free(Node2D.new()) as Node2D
	add_child(_world)
	_station = load("res://entities/structures/SpaceStation.tscn").instantiate() as SpaceStation
	_world.add_child(_station)
	await get_tree().process_frame
	await get_tree().physics_frame

func after_test() -> void:
	Freight.clear_all(get_tree())
	NavSystem.track_home()

func _pulse(at: Vector2) -> SonarPulse:
	var pulse: SonarPulse = auto_free(SonarPulse.new())
	_world.add_child(pulse)
	pulse.global_position = at
	pulse.set_process(false)
	return pulse

func _run(pulse: SonarPulse, seconds: float) -> void:
	for i in ceili(seconds / FRAME) + 2:
		pulse._process(FRAME)

func _mount(id: String) -> Mount:
	return Mount.for_section(get_tree(), id)

## Which of `m`'s cut-edge samples a tapped ring from `at` (in the Mount's space) touches.
func _touched_from(m: Mount, at: Vector2) -> Array[int]:
	var hits: Array[int] = []
	m._sonar.touched.connect(func(i: int, _a: float, _o: Vector2, _r: int) -> void: hits.append(i))
	var pulse := _pulse(m.to_global(at))
	pulse.send(1.0)
	_run(pulse, SonarPulse.LIFETIME)
	return hits

## The samples `hits` in `m`'s own space.
func _local(m: Mount, hits: Array[int]) -> Array[Vector2]:
	m._sonar.refresh()
	var pts := m._sonar.global_samples()
	var out: Array[Vector2] = []
	for i in hits:
		out.append(m.to_local(pts[i]))
	return out

# --- the cut edges ---

func test_an_empty_mount_s_outline_is_its_cut_edges_joined_up() -> void:
	# The tank was cut on three sides: one line round them, along the torch line
	var lines := _mount(Sections.FUEL_TANK).cut_lines()
	assert_int(lines.size()).is_equal(1)
	assert_int(lines[0].size()).is_equal(4)
	var edges := [[Vector2(0, 0), Vector2(10, 0), Vector2.DOWN], [Vector2(0, 0), Vector2(0, 8), Vector2.RIGHT]]
	var joined := Mount.join_edges(edges, 3.0)
	assert_int(joined.size()).is_equal(1)
	assert_array(Array(joined[0])).contains_exactly_in_any_order([Vector2(10, 3), Vector2(3, 3), Vector2(3, 8)])
	# Facing inward along it: (b - a).orthogonal() points into the gap
	var line := joined[0]
	assert_float((line[1] - line[0]).orthogonal().dot(Vector2(5, 5) - line[0])).is_greater(0.0)

func test_a_ring_lights_only_the_cut_faces_turned_toward_it() -> void:
	# From beside the tank's gap: the face beside the ring has its back to it
	var m := _mount(Sections.FUEL_TANK)
	var lit := _local(m, _touched_from(m, Vector2(150, 0)))
	assert_int(lit.size()).is_greater(0)
	for p in lit:
		assert_float(p.x).override_failure_message(str(p)).is_less(60.0)
	assert_bool(lit.any(func(p: Vector2) -> bool: return p.x < -60.0)).is_true()  # the far face, seen across the gap

func test_a_ring_lights_only_the_cut_edges_it_reaches() -> void:
	# From well out past the gap's open side, a tap only reaches the nearer half
	var m := _mount(Sections.FUEL_TANK)
	var from := Vector2(0, -275)
	var lit := _local(m, _touched_from(m, from))
	assert_int(lit.size()).is_greater(0)
	for p in lit:
		assert_float(p.distance_to(from)).override_failure_message(str(p)).is_less_equal(SonarPulse.END_RADIUS + SonarRing.TOL)
		assert_float(p.y).override_failure_message(str(p)).is_less(20.0)  # the bottom of the cut is out of reach

func test_the_cut_edges_block_nothing() -> void:
	var m := _mount(Sections.FUEL_TANK)
	assert_bool(m._sonar.blocks()).is_false()
	assert_bool(m._sonar.contains(m.global_position)).is_false()
	var ring := SonarRing.new(m.to_global(Vector2(0, -150)), 1.0, SonarPulse.END_RADIUS, 1.0, 6.0)
	ring.age = 0.5
	ring.advance(SonarPulse.active_surfaces(get_tree()))
	for k in ring._cand:
		assert_object(k).is_not_same(m._sonar)

# --- the glow and the found trace ---

func test_a_ring_lights_the_mount_and_starts_one_trace() -> void:
	var m := _mount(Sections.FUEL_TANK)
	var hits := _touched_from(m, Vector2(0, -150))
	assert_int(hits.size()).is_greater(1)
	assert_bool(m._glow.is_lit()).is_true()
	assert_int(m._glow.traces).is_equal(1)
	assert_bool(m._glow.is_tracing()).is_true()
	# A second ring is answered again, once
	var pulse := _pulse(m.to_global(Vector2(0, -150)))
	pulse.send(1.0)
	_run(pulse, SonarPulse.LIFETIME)
	assert_int(m._glow.traces).is_equal(2)

func test_the_trace_begins_where_the_ring_touched_first() -> void:
	# From out past one end of the cut: the trace starts at the sample nearest the ship
	var m := _mount(Sections.FUEL_TANK)
	var from := m.to_global(Vector2(40, -150))
	_touched_from(m, Vector2(40, -150))
	var pts := m._sonar.global_samples()
	var start := m._glow._trace_off.find(0)
	for i in pts.size():
		if m._sonar.faces(i, from):
			assert_float(pts[start].distance_to(from)).is_less_equal(pts[i].distance_to(from) + 0.01)

func test_the_trace_runs_both_ways_from_the_first_touch() -> void:
	var m := _mount(Sections.FUEL_TANK)
	var glow := m._glow
	var n := m._sonar.sample_count()
	glow._fit()
	glow._start_trace(n / 2)
	assert_int(glow._trace_off[n / 2]).is_equal(0)
	assert_int(glow._trace_off[n / 2 - 3]).is_equal(3)
	assert_int(glow._trace_off[n / 2 + 3]).is_equal(3)
	assert_int(glow._trace_span).is_equal(maxi(n / 2, n - 1 - n / 2))

func test_a_seated_mount_does_not_glow() -> void:
	var m := _mount(Sections.FUEL_TANK)
	var tank := Freight.spawn_section(_world, Sections.FUEL_TANK, m.global_position, m.global_rotation)
	m.seat(tank)
	await await_millis(int(Mount.SEAT_TIME * 1000.0) + 150)
	assert_bool(m._sonar.is_in_group(SonarSurface.GROUP)).is_false()
	var hits := _touched_from(m, Vector2(0, -150))
	assert_int(hits.size()).is_equal(0)
	assert_bool(m._glow.is_lit()).is_false()
	assert_int(m._glow.traces).is_equal(0)
	# Taken back out (a load from before it was seated): it lights again
	m.refresh()
	assert_bool(m._sonar.is_in_group(SonarSurface.GROUP)).is_true()
