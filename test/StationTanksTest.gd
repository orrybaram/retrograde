extends GdUnitTestSuite

## SR-7's two fuel tanks: the left one blown out and leaking, the right one (the FUEL TANK
## Section) carrying a level meter that comes home empty.

var _station: SpaceStation

func before_test() -> void:
	_station = auto_free(load("res://entities/structures/SpaceStation.tscn").instantiate()) as SpaceStation
	add_child(_station)
	await get_tree().process_frame

func after_test() -> void:
	Freight.clear_all(get_tree())
	NavSystem.track_home()

func _gauge() -> FuelGauge:
	return _station.get_node("Visuals/FuelTank/Gauge") as FuelGauge

func _breach() -> TankBreach:
	return _station.get_node("Visuals/FuelTankL/Breach") as TankBreach


func test_the_left_tank_leaks() -> void:
	var breach := _breach()
	for i in 60:
		breach._process(1.0 / 30.0)
	assert_int(breach.puff_count()).is_greater(0)


func test_the_leak_sputters_but_never_stops() -> void:
	var lo := INF
	var hi := 0.0
	for i in 400:
		var r := TankBreach.rate_at(i * 0.05)
		lo = minf(lo, r)
		hi = maxf(hi, r)
	assert_float(lo).is_greater_equal(TankBreach.RATE_MIN)
	assert_float(hi - lo).override_failure_message("it comes in gasps").is_greater(3.0)


func test_the_hole_is_on_the_left_tank() -> void:
	var tank := (_station.get_node("Visuals/FuelTankL") as Polygon2D).polygon
	assert_bool(Geometry2D.is_point_in_polygon(TankBreach.HOLE_AT, tank)).is_true()


func test_the_right_tank_comes_home_empty() -> void:
	var gauge := _gauge()
	assert_float(gauge.level).is_equal(0.0)
	assert_float(gauge.fill_rect().size.y).is_equal(0.0)


func test_the_meter_sits_on_the_right_tank() -> void:
	var tank := (_station.get_node("Visuals/FuelTank") as Polygon2D).polygon
	var slot := FuelGauge.SLOT
	for corner in [slot.position, slot.end, Vector2(slot.position.x, slot.end.y), Vector2(slot.end.x, slot.position.y)]:
		assert_bool(Geometry2D.is_point_in_polygon(corner, tank)).is_true()


func test_the_meter_fills_from_the_bottom() -> void:
	var gauge := _gauge()
	gauge.snap(0.5)
	var fill := gauge.fill_rect()
	assert_float(fill.end.y).is_equal_approx(FuelGauge.SLOT.grow(-1.5).end.y, 0.01)
	assert_float(fill.size.y).is_equal_approx(FuelGauge.SLOT.grow(-1.5).size.y * 0.5, 0.01)
	gauge.level = 2.0
	assert_float(gauge.level).is_equal(1.0)


# --- wear across the hull ---

func _damage() -> HullDamage:
	return _station.get_node("HullDamage") as HullDamage


func test_the_hull_is_marked_all_over() -> void:
	assert_int(_damage().mark_list().size()).is_greater((auto_free(HullDamage.new()) as HullDamage).marks / 2)
	assert_int(_damage().flap_list().size()).is_greater(0)


func test_the_sections_stay_clean() -> void:
	for part in ["Visuals/FuelTank", "Visuals/SolarArray", "Visuals/DorsalArm", "Visuals/CentralCore"]:
		var poly := (_station.get_node(part) as Polygon2D).polygon
		for m in _damage().mark_list():
			assert_bool(Geometry2D.is_point_in_polygon(m["at"], poly)).override_failure_message(
				"%s is clean: a mark landed on it" % part).is_false()


func test_the_damage_is_the_same_every_run() -> void:
	var other: SpaceStation = auto_free(load("res://entities/structures/SpaceStation.tscn").instantiate())
	add_child(other)
	await get_tree().process_frame
	var a := _damage().mark_list()
	var b := (other.get_node("HullDamage") as HullDamage).mark_list()
	assert_int(b.size()).is_equal(a.size())
	assert_vector(b[0]["at"]).is_equal(a[0]["at"])
