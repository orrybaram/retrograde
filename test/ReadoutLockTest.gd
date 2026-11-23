extends GdUnitTestSuite

## Lock brackets on what the ship is working on (ui/ReadoutLock.gd): held while the owner
## holds it, closing from wide, and nothing at all for a plain read.

var _lock: ReadoutLock

func before_test() -> void:
	_lock = auto_free(ReadoutLock.new()) as ReadoutLock
	add_child(_lock)

func _readout() -> Readout:
	var owner_node := auto_free(Node2D.new()) as Node2D
	add_child(owner_node)
	var r := Readout.new()
	r.heading = "MOUNT"
	r.title = "FUEL TANK"
	owner_node.add_child(r)
	return r


func test_the_brackets_start_wide_and_close_around_the_thing() -> void:
	var rect := Rect2(100, 100, 60, 40)
	var open := ReadoutLock.bracket_box(rect, 0.0)
	var shut := ReadoutLock.bracket_box(rect, 1.0)
	assert_bool(open.encloses(shut)).is_true()
	assert_bool(shut.encloses(rect)).is_true()
	assert_float(shut.position.x).is_equal(rect.position.x - ReadoutLock.PAD)
	assert_float(ReadoutLock.closing(0.0)).is_equal(0.0)
	assert_float(ReadoutLock.closing(ReadoutLock.CLOSE_TIME)).is_equal(1.0)


func test_a_read_draws_no_lock() -> void:
	var r := _readout()
	EventBus.readout_read.emit(r, [ReadoutRow.make("STATE", "EMPTY")])
	assert_bool(_lock.is_locked(r)).is_false()


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


func test_a_held_lock_stays_and_goes_when_let_go() -> void:
	var r := _readout()
	_lock.hold(r, true)
	_lock._process(0.1)
	assert_bool(_lock.is_locked(r)).is_true()
	_lock._process(10.0)
	assert_bool(_lock.is_locked(r)).override_failure_message("held, it never times out").is_true()
	_lock.hold(r, false)
	assert_bool(_lock.is_locked(r)).is_false()
