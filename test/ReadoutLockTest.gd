extends GdUnitTestSuite

## What ties a read to its thing: a tether straight out of the corner entry, and brackets
## closing where it lands, both held as long as the entry (ui/ReadoutLock.gd).

var _log: ContactLog
var _lock: ReadoutLock

func before_test() -> void:
	_log = auto_free(ContactLog.new()) as ContactLog
	add_child(_log)
	_lock = auto_free(ReadoutLock.new()) as ReadoutLock
	_lock.contact_log = _log
	add_child(_lock)

func _readout() -> Readout:
	var owner_node := auto_free(Node2D.new()) as Node2D
	add_child(owner_node)
	var r := Readout.new()
	r.heading = "MOUNT"
	r.title = "FUEL TANK"
	owner_node.add_child(r)
	return r

func _rows() -> Array:
	return [ReadoutRow.make("STATE", "EMPTY")]

## Read `r` the way the game does: the log takes the signal first, then the lock.
func _read(r: Readout) -> void:
	_log.show_read(r, _rows())
	_lock.show_read(r, _rows())


func test_the_tether_draws_out_then_the_brackets_close() -> void:
	var start := ReadoutLock.timing(0.0)
	assert_float(start.x).is_equal(0.0)
	assert_float(start.y).is_equal(0.0)
	var landed := ReadoutLock.timing(ReadoutLock.DRAW_OUT)
	assert_float(landed.x).override_failure_message("the tether has reached it").is_equal(1.0)
	assert_float(landed.y).override_failure_message("the brackets start where it lands").is_equal(0.0)
	var shut := ReadoutLock.timing(ReadoutLock.DRAW_OUT + ReadoutLock.CLOSE_TIME)
	assert_float(shut.y).is_equal(1.0)


func test_the_brackets_start_wide_and_close_around_the_thing() -> void:
	var rect := Rect2(100, 100, 60, 40)
	var open := ReadoutLock.bracket_box(rect, 0.0)
	var shut := ReadoutLock.bracket_box(rect, 1.0)
	assert_bool(open.encloses(shut)).is_true()
	assert_bool(shut.encloses(rect)).is_true()
	assert_float(shut.position.x).is_equal(rect.position.x - ReadoutLock.PAD)


func test_the_tether_runs_straight_to_the_nearest_corner() -> void:
	var box := Rect2(100, 100, 40, 40)
	var path := ReadoutLock.tether_path(Vector2(600, 400), box)
	assert_int(path.size()).is_equal(2)
	assert_vector(path[0]).override_failure_message("just left of the heading") \
		.is_equal(Vector2(600 - ReadoutLock.PORT_GAP, 400))
	assert_vector(path[1]).is_equal(box.end)


func test_a_read_locks_and_the_lock_lives_as_long_as_its_entry() -> void:
	var r := _readout()
	_read(r)
	assert_bool(_lock.is_locked(r)).is_true()
	_log._process(ContactLog.HOLD + ContactLog.FADE_TIME + 10.0)
	_lock._process(0.1)
	assert_bool(_lock.is_locked(r)).override_failure_message("no entry, no lock").is_false()


func test_bounds_come_from_the_owner_when_it_has_them() -> void:
	var station := auto_free(load("res://entities/structures/SpaceStation.tscn").instantiate()) as Node2D
	add_child(station)
	await get_tree().process_frame
	var mount := Mount.for_section(get_tree(), Sections.FUEL_TANK)
	var bounds := Readout.on(mount).world_bounds()
	assert_bool(bounds.has_area()).override_failure_message("the gap the tank leaves").is_true()
	mount.seated = true
	assert_bool(Readout.on(mount).world_bounds().has_area()).override_failure_message("the tank, once home").is_true()
	Freight.clear_all(get_tree())


func test_a_held_lock_stays_with_no_entry_and_goes_when_let_go() -> void:
	var r := _readout()
	_lock.hold(r, true)
	_lock._process(0.1)
	assert_bool(_lock.is_locked(r)).override_failure_message("held with nothing in the corner").is_true()
	assert_float(ReadoutLock.timing(_lock._locks.values()[0].age).y) \
		.override_failure_message("no tether to wait for: the brackets close at once").is_greater(0.0)
	_lock.hold(r, false)
	_lock._process(0.1)
	assert_bool(_lock.is_locked(r)).is_false()


func test_a_held_lock_outlives_its_entry() -> void:
	var r := _readout()
	_read(r)
	_lock.hold(r, true)
	_log._process(ContactLog.HOLD + ContactLog.FADE_TIME + 10.0)
	_lock._process(0.1)
	assert_bool(_lock.is_locked(r)).is_true()
