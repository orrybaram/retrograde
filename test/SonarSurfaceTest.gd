extends GdUnitTestSuite

## A Sweep ring meets the world: rays stepped against SonarSurfaces, so the station, planets
## and wrecks shadow what is behind them, and rock drains reach until only a long hold gets
## through. The rings here are stepped by hand, a frame at a time.

const FRAME := 1.0 / 60.0

var _scrap: ScrapNode
var _gs: GameState

func before_test() -> void:
	_gs = auto_free(GameState.new())
	add_child(_gs)
	_scrap = ResourceNodePool.get_instance("Scrap1", self) as ScrapNode
	await get_tree().process_frame

func after_test() -> void:
	if is_instance_valid(_scrap):
		ResourceNodePool.return_instance(_scrap)

## A pulse at `at`, not processing on its own: the test steps it.
func _pulse(at: Vector2, parent: Node = self) -> SonarPulse:
	var pulse: SonarPulse = auto_free(SonarPulse.new())
	parent.add_child(pulse)
	pulse.global_position = at
	pulse.set_process(false)
	return pulse

## Step `pulse` for `seconds` (all of a ring's life by default).
func _run(pulse: SonarPulse, seconds: float) -> void:
	for i in ceili(seconds / FRAME) + 2:
		pulse._process(FRAME)

## A tapped ring from `at`, run to the end.
func _tap(at: Vector2) -> void:
	var pulse := _pulse(at)
	pulse.send(1.0)
	_run(pulse, SonarPulse.LIFETIME)

func _planet(at: Vector2, radius: float) -> Planet:
	var planet := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	planet.radius = radius
	planet.enable_orbiting = false
	add_child(planet)
	planet.global_position = at
	return planet

func _station(at := Vector2.ZERO) -> SpaceStation:
	var world: Node2D = auto_free(Node2D.new())
	add_child(world)
	var station := load("res://entities/structures/SpaceStation.tscn").instantiate() as SpaceStation
	world.add_child(station)
	station.global_position = at
	return station

## A square of rock `size` px across at `at`.
func _rock(at: Vector2, size: float) -> Node2D:
	var rock: Node2D = auto_free(Node2D.new())
	add_child(rock)
	rock.global_position = at
	var shape := CollisionPolygon2D.new()
	var h := size / 2.0
	shape.polygon = PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	rock.add_child(shape)
	SonarSurface.attach(rock, shape, SonarSurface.Preset.ROCK)
	return rock

class Listener extends Node2D:
	var touched := 0
	var strength := 0.0
	func sonar_point() -> Vector2:
		return global_position
	func on_sonar_touched(s := 1.0) -> void:
		touched += 1
		strength = s

func _listener(at: Vector2, parent: Node = self) -> Listener:
	var l: Listener = auto_free(Listener.new())
	parent.add_child(l)
	l.global_position = at
	l.add_to_group("sonar_listeners")
	return l

# --- the surfaces ---

func test_a_planet_station_and_debris_carry_surfaces() -> void:
	var planet := _planet(Vector2(5000, 0), 200.0)
	var station := _station(Vector2(-5000, 0))
	await get_tree().process_frame
	var ps := planet.get_node("SonarSurface") as SonarSurface
	assert_object(ps).is_not_null()
	assert_bool(ps.get_sonar_material().is_solid()).is_true()
	ps.refresh()
	assert_bool(ps.contains(planet.global_position + Vector2(190, 0))).is_true()
	assert_bool(ps.contains(planet.global_position + Vector2(210, 0))).is_false()
	var ss := station.get_node("SonarSurface") as SonarSurface
	assert_bool(ss.is_in_group(SonarSurface.GROUP)).is_true()
	assert_object(ss.get_sonar_material()).is_same(SonarMaterial.PLATE)

## Where the station's own collision is solid right now (its cut pieces, while Mounts are empty).
func _solid_at(station: SpaceStation, station_point: Vector2) -> bool:
	for child in station.get_children():
		var c := child as CollisionPolygon2D
		if c and not c.disabled and c.is_inside_tree() and not c.is_queued_for_deletion() \
				and Geometry2D.is_point_in_polygon(c.transform.affine_inverse() * station_point, c.polygon):
			return true
	return false

func test_the_station_surface_follows_the_cut_hull() -> void:
	var station := _station()
	await get_tree().process_frame
	await get_tree().process_frame
	var ss := station.get_node("SonarSurface") as SonarSurface
	ss.refresh()
	# The Mounts are empty: their gaps are open to a ring, the core is not
	for m in get_tree().get_nodes_in_group("mounts"):
		assert_bool(ss.contains((m as Mount).global_position)).override_failure_message(m.name).is_false()
	assert_bool(ss.contains(station.to_global(Vector2(0, 15)))).is_true()
	# All seated, the hull is whole again: the ring meets what a ship would
	for m in get_tree().get_nodes_in_group("mounts"):
		(m as Mount)._show_seated(true)
	await get_tree().process_frame
	await get_tree().process_frame
	ss.refresh()
	var whole := 0
	for m in get_tree().get_nodes_in_group("mounts"):
		var at := (m as Mount).position
		assert_bool(ss.contains(station.to_global(at))).override_failure_message(m.name).is_equal(_solid_at(station, at))
		whole += 1 if _solid_at(station, at) else 0
	assert_int(whole).is_greater(0)

func test_pooled_debris_is_rock_only_while_it_is_out() -> void:
	var debris := ResourceNodePool.get_instance("Debris1", self) as DebrisNode
	await get_tree().process_frame
	var s := debris.get_node("SonarSurface") as SonarSurface
	assert_object(s.get_sonar_material()).is_same(SonarMaterial.ROCK)
	assert_bool(s.is_in_group(SonarSurface.GROUP)).is_true()
	ResourceNodePool.return_instance(debris)
	assert_bool(s.is_in_group(SonarSurface.GROUP)).is_false()

# --- shadows ---

func test_scrap_behind_a_planet_is_not_found() -> void:
	_planet(Vector2(160, 0), 80.0)
	_scrap.global_position = Vector2(265, 0)
	await get_tree().process_frame
	_tap(Vector2.ZERO)
	assert_bool(_scrap.revealed).is_false()

func test_the_same_scrap_is_found_from_an_open_line() -> void:
	_planet(Vector2(160, 0), 80.0)
	_scrap.global_position = Vector2(265, 0)
	await get_tree().process_frame
	_tap(Vector2(265, 260))
	assert_bool(_scrap.revealed).is_true()

func test_scrap_behind_the_station_is_not_found_but_is_from_the_open() -> void:
	var station := _station()
	_scrap.global_position = station.to_global(Vector2(300, 15))
	await get_tree().process_frame
	var strength := 3.0
	var behind := _pulse(station.to_global(Vector2(-450, 15)))
	behind.send(strength)
	_run(behind, SonarPulse.LIFETIME * strength)
	assert_bool(_scrap.revealed).override_failure_message("through the hull").is_false()
	var open := _pulse(station.to_global(Vector2(300, 415)))
	open.send(strength)
	_run(open, SonarPulse.LIFETIME * strength)
	assert_bool(_scrap.revealed).is_true()

func test_a_tap_is_lost_in_rock_and_a_long_hold_gets_through() -> void:
	_rock(Vector2(120, 0), 80.0)
	_scrap.global_position = Vector2(240, 0)
	await get_tree().process_frame
	var tap := _pulse(Vector2.ZERO)
	tap.send(SonarPulse.strength_for(0.0))
	_run(tap, SonarPulse.LIFETIME)
	assert_bool(_scrap.revealed).override_failure_message("a tap").is_false()
	var held := SonarPulse.strength_for(2.0)
	var hold := _pulse(Vector2.ZERO)
	hold.send(held)
	_run(hold, SonarPulse.LIFETIME * held)
	assert_bool(_scrap.revealed).override_failure_message("a 2 s hold").is_true()

func test_rings_are_heard_as_they_pass_not_when_they_leave() -> void:
	var near := _listener(Vector2(40, 0))
	var far := _listener(Vector2(240, 0))
	await get_tree().process_frame
	var pulse := _pulse(Vector2.ZERO)
	pulse.send(1.0)
	_run(pulse, SonarPulse.time_to_reach(120.0))
	assert_int(near.touched).is_equal(1)
	assert_int(far.touched).is_equal(0)
	_run(pulse, SonarPulse.LIFETIME)
	assert_int(far.touched).is_equal(1)
	assert_int(near.touched).is_equal(1)

# --- inside the station ---

func test_a_listener_inside_the_hull_hears_the_ring_at_the_hull() -> void:
	var station := _station()
	var inside := _listener(station.to_global(Vector2(0, 15)), station)
	await get_tree().process_frame
	var strength := 3.0
	var pulse := _pulse(station.to_global(Vector2(-450, 15)))
	pulse.send(strength)
	_run(pulse, SonarPulse.LIFETIME * strength)
	assert_int(inside.touched).is_equal(1)

func test_the_dish_ring_leaves_its_own_station() -> void:
	var station := _station()
	await get_tree().process_frame
	var dish := station.get_node("Visuals/KeelLower/CommDish") as CommDish
	# Straight up from the dish, through the whole hull
	var above := _listener(dish.global_position + Vector2(0, -900))
	dish.ping()
	var ring := dish.get_node("Ping") as SonarPulse
	ring.set_process(false)
	_run(ring, SonarPulse.time_to_reach(900.0, CommDish.PING_STRENGTH) + 0.3)
	assert_int(above.touched).override_failure_message("the dish's own ring").is_equal(1)
	# The same ring sent from there by anything else is stopped by the hull
	var other := _pulse(dish.global_position)
	other.send(CommDish.PING_STRENGTH)
	_run(other, SonarPulse.time_to_reach(900.0, CommDish.PING_STRENGTH) + 0.3)
	assert_int(above.touched).is_equal(1)

# --- far answers ---

func _cargo_bay(at: Vector2) -> Freight:
	_gs.progress.flag(Progress.CORE_STARTED)
	var f: Freight = auto_free(Freight.new())
	Components.apply(f, Components.CARGO_BAY)
	add_child(f)
	f.global_position = at
	return f

func _echoes(f: Freight) -> int:
	return f._visual.get_children().filter(func(c): return c is SonarEcho).size()

func test_a_far_answer_comes_back_in_the_open() -> void:
	var bay := _cargo_bay(Vector2(2000, 0))
	await get_tree().process_frame
	var strength := 3.0
	var pulse := _pulse(Vector2.ZERO)
	pulse.send(strength)
	_run(pulse, SonarPulse.LIFETIME * strength)
	assert_int(_echoes(bay)).is_equal(1)

func test_a_planet_in_the_way_silences_a_far_answer() -> void:
	var bay := _cargo_bay(Vector2(2000, 0))
	_planet(Vector2(500, 0), 150.0)
	await get_tree().process_frame
	var strength := 3.0
	var pulse := _pulse(Vector2.ZERO)
	pulse.send(strength)
	_run(pulse, SonarPulse.LIFETIME * strength)
	assert_int(_echoes(bay)).is_equal(0)

func test_a_far_answer_is_lost_in_thick_rock() -> void:
	var bay := _cargo_bay(Vector2(2000, 0))
	_rock(Vector2(600, 0), 400.0)
	await get_tree().process_frame
	var strength := 3.0
	var pulse := _pulse(Vector2.ZERO)
	pulse.send(strength)
	_run(pulse, SonarPulse.LIFETIME * strength)
	assert_int(_echoes(bay)).is_equal(0)

# --- buried Freight ---

func test_a_buried_lug_sticks_out_of_the_ground_and_answers() -> void:
	_gs.progress.flag(Progress.CORE_STARTED)
	var veld := _planet(Vector2.ZERO, 2400.0)
	var wreck: HaulerWreck = auto_free(HaulerWreck.new())
	veld.add_child(wreck)
	wreck.ensure_cargo_bay()
	var f := wreck.find_piece()
	auto_free(f)
	await get_tree().process_frame
	assert_bool(f.is_buried()).is_true()
	var ground := veld.get_node("SonarSurface") as SonarSurface
	ground.refresh()
	assert_bool(ground.contains(f.lug_global())).override_failure_message("the Lug is out of the ground").is_false()
	var up := (f.lug_global() - veld.global_position).normalized()
	var pulse := _pulse(f.lug_global() + up * 150.0)
	pulse.send(1.0)
	_run(pulse, SonarPulse.LIFETIME)
	assert_int(_echoes(f)).is_equal(1)

# --- reactive outlines (the hook a Mount's glow hangs off) ---

func test_a_reactive_outline_hears_where_the_ring_touched_it() -> void:
	var holder: Node2D = auto_free(Node2D.new())
	add_child(holder)
	holder.global_position = Vector2(150, 0)
	var mat := SonarMaterial.make(INF, 1.0, true)
	mat.reactive = true
	var s := SonarSurface.new()
	s.sonar_material = mat
	holder.add_child(s)
	s.set_polygons([PackedVector2Array([Vector2(-20, -20), Vector2(20, -20), Vector2(20, 20), Vector2(-20, 20)])])
	var hits: Array[int] = []
	s.touched.connect(func(i: int, _a: float, _o: Vector2, _r: int) -> void: hits.append(i))
	await get_tree().process_frame
	var pulse := _pulse(Vector2.ZERO)
	pulse.send(1.0)
	_run(pulse, SonarPulse.LIFETIME)
	assert_int(hits.size()).is_greater(0)
	s.refresh()
	var pts := s.global_samples()
	for i in hits:
		# Only the face toward the ring: x = 130
		assert_float(pts[i].x).override_failure_message(str(pts[i])).is_less(150.0)

# --- soft shadows and echoes ---

## A solid disc of hull plate, `radius` px, at `at`.
func _post(at: Vector2, radius: float) -> Node2D:
	var post: Node2D = auto_free(Node2D.new())
	add_child(post)
	post.global_position = at
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	post.add_child(shape)
	SonarSurface.attach(post, shape, SonarSurface.Preset.PLATE)
	return post

func test_the_ring_is_read_along_the_bearing_asked() -> void:
	# A shadow at 100 degrees is there, and only there: 60 degrees is open (bearings are not
	# rounded to whole radians)
	_post(Vector2.from_angle(deg_to_rad(100.0)) * 110.0, 30.0)
	var pulse := _pulse(Vector2.ZERO)
	pulse.send(1.0)
	_run(pulse, SonarPulse.LIFETIME * 0.8)
	var ring: SonarRing = pulse._rings[0]
	assert_float(ring.amp_at(deg_to_rad(100.0), 170.0)).is_less(SonarRing.FIND)
	assert_float(ring.amp_at(deg_to_rad(60.0), 170.0)).is_greater_equal(SonarRing.FIND)
	assert_float(ring.amp_toward(Vector2.from_angle(deg_to_rad(60.0)) * 170.0)).is_greater_equal(SonarRing.FIND)

func test_a_small_shadow_fills_back_in_with_distance() -> void:
	_post(Vector2(100, 0), 12.0)
	var close := _listener(Vector2(120, 0))
	var far := _listener(Vector2(260, 0))
	await get_tree().process_frame
	var pulse := _pulse(Vector2.ZERO)
	pulse.send(1.0)
	_run(pulse, SonarPulse.LIFETIME)
	assert_int(close.touched).override_failure_message("right behind it").is_equal(0)
	assert_int(far.touched).override_failure_message("well behind it").is_equal(1)

func test_the_ring_fades_into_a_shadow_rather_than_ending() -> void:
	_post(Vector2(150, 0), 50.0)
	await get_tree().process_frame
	var pulse := _pulse(Vector2.ZERO)
	pulse.send(1.0)
	_run(pulse, SonarPulse.time_to_reach(260.0))
	var ring: SonarRing = pulse._rings[0]
	var graded := 0
	for i in SonarRing.RAYS:
		if ring._amp[i] > 0.05 and ring._amp[i] < 0.95:
			graded += 1
	assert_int(graded).is_greater(4)
	assert_float(ring.amp_toward(Vector2(260, 0))).override_failure_message("still dark in the middle").is_less(SonarRing.FIND)

func test_hard_plate_throws_a_faint_arc_back() -> void:
	_post(Vector2(100, 0), 30.0)
	await get_tree().process_frame
	var pulse := _pulse(Vector2.ZERO)
	pulse.send(1.0)
	_run(pulse, SonarPulse.time_to_reach(100.0))
	var ring: SonarRing = pulse._rings[0]
	assert_int(ring.bounce_count()).is_greater(3)
	var back := 0
	for j in ring.bounce_count():
		back += 1 if ring._bounce_dir[j].x < 0.0 else 0
		assert_float(ring._bounce_amp[j]).is_less_equal(SonarRing.BOUNCE_KEEP + 0.001)
		if ring._bounce_ray[j] == 0:
			# Head on: straight back
			assert_float(ring._bounce_dir[j].x).is_less(-0.99)
	assert_int(back).override_failure_message("mostly back toward the ship").is_greater(ring.bounce_count() / 2)
	_run(pulse, SonarPulse.LIFETIME)
	assert_int(pulse.ring_count()).is_equal(0)

func test_the_presets_all_echo_and_only_rock_lets_a_ring_through() -> void:
	assert_bool(SonarMaterial.PLATE.echo and SonarMaterial.ROCK.echo and SonarMaterial.PLANET.echo).is_true()
	assert_bool(SonarMaterial.ROCK.is_solid()).is_false()

# --- cost ---

func test_a_strong_ring_by_the_station_is_cheap() -> void:
	var station := _station()
	await get_tree().process_frame
	await get_tree().process_frame
	var strength := 5.0
	var pulse := _pulse(station.to_global(Vector2(-500, 15)))
	pulse.send(strength)
	var worst := 0
	var total := 0
	var frames := 0
	while pulse.ring_count() > 0:
		var t0 := Time.get_ticks_usec()
		pulse._process(FRAME)
		var used := Time.get_ticks_usec() - t0
		worst = maxi(worst, used)
		total += used
		frames += 1
	var mean := float(total) / frames / 1000.0
	print("SonarSurfaceTest: strength-%d ring by the station, %d frames, mean %.3f ms, worst %.3f ms" % [
		strength, frames, mean, worst / 1000.0])
	assert_float(mean).is_less(2.0)

## Draws a ring on demand and times it.
class RingCanvas extends Node2D:
	var ring: SonarRing
	var used := -1
	func _draw() -> void:
		var t0 := Time.get_ticks_usec()
		ring.draw(self)
		used = Time.get_ticks_usec() - t0

func test_drawing_a_strong_ring_is_cheap() -> void:
	var station := _station()
	await get_tree().process_frame
	var pulse := _pulse(station.to_global(Vector2(-500, 15)))
	pulse.send(5.0)
	_run(pulse, 2.0)
	var canvas: RingCanvas = auto_free(RingCanvas.new())
	canvas.ring = pulse._rings[0]
	add_child(canvas)
	canvas.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	print("SonarSurfaceTest: drawing a strength-5 ring by the station, %.3f ms" % (canvas.used / 1000.0))
	assert_int(canvas.used).is_greater_equal(0)
	assert_int(canvas.used).is_less(2000)

func test_a_strong_ring_in_a_debris_field_is_cheap() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 60:
		_rock(Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(120.0, 1300.0), rng.randf_range(20.0, 70.0))
	await get_tree().process_frame
	var strength := 5.0
	var pulse := _pulse(Vector2.ZERO)
	pulse.send(strength)
	var worst := 0
	var total := 0
	var frames := 0
	while pulse.ring_count() > 0:
		var t0 := Time.get_ticks_usec()
		pulse._process(FRAME)
		var used := Time.get_ticks_usec() - t0
		worst = maxi(worst, used)
		total += used
		frames += 1
	var mean := float(total) / frames / 1000.0
	print("SonarSurfaceTest: strength-%d ring among 60 rocks, %d frames, mean %.3f ms, worst %.3f ms" % [
		strength, frames, mean, worst / 1000.0])
	assert_float(mean).is_less(2.0)
