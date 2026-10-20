extends GdUnitTestSuite

## A Readout reads, every row at once, when the ship comes within its reach, and the read
## holds in the ledger (docs/SWEEP.md §10).

var _gs: GameState
var _ship: Ship
var _reads: Array = []

func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	add_child(_gs)
	_ship = auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	add_child(_ship)
	_ship.set_physics_process(false)
	_ship.global_position = Vector2(100000, 0)
	_reads.clear()
	EventBus.readout_read.connect(_on_read)

func after_test() -> void:
	EventBus.readout_read.disconnect(_on_read)

func _on_read(readout: Node, rows: Array) -> void:
	_reads.append({"readout": readout, "rows": rows})

func _readout(owner_node: Node = null, at := Vector2.ZERO) -> Readout:
	var r := Readout.new()
	r.key = "test_thing_%d" % get_child_count()
	r.heading = "MOUNT"
	r.title = "TEST"
	r.rows = [ReadoutRow.make("STATE", "EMPTY"), ReadoutRow.make("EDGE", "TORCH CUT"),
		ReadoutRow.make("FRACTURE", "NONE")]
	var parent: Node = owner_node if owner_node else auto_free(Node2D.new())
	if parent.get_parent() == null:
		add_child(parent)
	parent.add_child(r)
	r.set_physics_process(false)
	r.global_position = at
	return r

## Move the ship to `at` and let every readout look.
func _fly_to(at: Vector2) -> void:
	_ship.global_position = at
	for node in get_tree().get_nodes_in_group("readouts"):
		(node as Readout)._physics_process(0.0)

class LiveOwner extends Node2D:
	var seated := false
	func readout_rows() -> Array[ReadoutRow]:
		return [ReadoutRow.make("STATE", "SEATED" if seated else "EMPTY")]


func test_coming_close_reads_every_row_at_once() -> void:
	var r := _readout()
	_fly_to(Vector2(r.reach + 1.0, 0))
	assert_int(_reads.size()).override_failure_message("not yet in reach").is_equal(0)
	_fly_to(Vector2(r.reach - 1.0, 0))
	assert_int(_reads.size()).is_equal(1)
	assert_object(_reads[0].readout).is_same(r)
	assert_int(_reads[0].rows.size()).is_equal(3)


func test_it_reads_once_an_approach() -> void:
	var r := _readout()
	_fly_to(Vector2(r.reach * 0.5, 0))
	_fly_to(Vector2(r.reach * 0.6, 0))
	_fly_to(Vector2(r.reach + Readout.LEAVE_MARGIN * 0.5, 0))
	_fly_to(Vector2(r.reach * 0.5, 0))
	assert_int(_reads.size()).override_failure_message("drifting on the edge reads nothing more").is_equal(1)
	_fly_to(Vector2(r.reach + Readout.LEAVE_MARGIN + 1.0, 0))
	_fly_to(Vector2(r.reach * 0.5, 0))
	assert_int(_reads.size()).override_failure_message("away and back reads again").is_equal(2)


func test_of_several_in_reach_only_the_nearest_reads() -> void:
	var near := _readout(null, Vector2(40, 0))
	var far := _readout(null, Vector2(-150, 0))
	_fly_to(Vector2.ZERO)
	assert_int(_reads.size()).is_equal(1)
	assert_object(_reads[0].readout).is_same(near)
	_fly_to(Vector2(-120, 0))
	assert_object(_reads[-1].readout).override_failure_message("its turn once it is nearest").is_same(far)


func test_the_sweep_reads_nothing() -> void:
	var r := _readout()
	assert_bool(r.is_in_group("sonar_listeners")).is_false()


func test_an_owner_with_live_state_gives_the_rows() -> void:
	var owner_node := auto_free(LiveOwner.new()) as LiveOwner
	var r := _readout(owner_node)
	assert_str(r.rows_now()[0].value).is_equal("EMPTY")
	owner_node.seated = true
	assert_str(r.rows_now()[0].value).is_equal("SEATED")


func test_a_read_holds_in_the_ledger() -> void:
	var r := _readout()
	assert_bool(r.is_read()).is_false()
	r.read()
	assert_bool(r.is_read()).is_true()
	assert_bool(_gs.progress.holds(Progress.READ_READOUTS, r.key)).is_true()
	assert_object(Readout.on(r.get_parent())).is_same(r)


func test_every_mount_on_sr7_carries_one() -> void:
	var station := auto_free(load("res://entities/structures/SpaceStation.tscn").instantiate()) as Node2D
	add_child(station)
	await get_tree().process_frame
	for id in [Sections.FUEL_TANK, Sections.SOLAR_ARRAY, Sections.DORSAL_ARM]:
		var m := Mount.for_section(get_tree(), id)
		var r := Readout.on(m)
		assert_object(r).override_failure_message("%s's Mount has a readout" % id).is_not_null()
		assert_str(r.title).is_equal(Sections.DATA[id]["label"])
		assert_str(r.category).is_equal("SR-7")
	var fuel := Readout.on(Mount.for_section(get_tree(), Sections.FUEL_TANK))
	var rows := fuel.rows_now()
	assert_str(rows[0].value).is_equal("EMPTY")
	assert_str(rows[1].label).is_equal("SECTION")
	Mount.for_section(get_tree(), Sections.FUEL_TANK).seated = true
	rows = fuel.rows_now()
	assert_str(rows[0].value).is_equal("SEATED")
	assert_bool(rows.any(func(row: ReadoutRow) -> bool: return row.label == "SECTION")) \
		.override_failure_message("nothing to mark once it is home").is_false()
	Freight.clear_all(get_tree())


class KeyedOwner extends Node2D:
	func save_key() -> String:
		return "HomeSystem/Veld"


func test_under_an_owner_with_a_save_key_the_key_is_a_prefix() -> void:
	var r := _readout(auto_free(KeyedOwner.new()))
	r.key = "gate"
	assert_str(r.ledger_key()).is_equal("gate:HomeSystem/Veld")
	r.read()
	assert_bool(_gs.progress.holds(Progress.READ_READOUTS, "gate:HomeSystem/Veld")).is_true()


func test_an_undecipherable_thing_reads_as_noise_of_the_same_shape() -> void:
	var r := _readout()
	r.undecipherable = true
	assert_str(r.shown_heading()).is_not_equal("MOUNT")
	assert_int(r.shown_heading().length()).is_equal("MOUNT".length())
	assert_str(r.shown_heading()).override_failure_message("the same noise every time").is_equal(r.shown_heading())
	var rows := r.shown_rows()
	assert_int(rows.size()).is_equal(3)
	assert_str(rows[1].value).is_not_equal("TORCH CUT")
	assert_str(rows[1].value[5]).override_failure_message("spaces survive").is_equal(" ")
	for c in rows[0].label:
		assert_bool(RobotFaces.GLITCH_CHARS.contains(c)).is_true()
	r.read()
	assert_str(_reads[0].rows[0].value).override_failure_message("what goes out is the noise").is_not_equal("EMPTY")
	assert_bool(r.is_read()).override_failure_message("it was still read").is_true()


func test_gates_carry_an_undecipherable_one() -> void:
	var gate := auto_free(load("res://entities/structures/Gate.tscn").instantiate()) as Gate
	var r := Readout.on(gate)
	assert_object(r).is_not_null()
	assert_bool(r.undecipherable).is_true()
	assert_str(r.key).is_equal("gate")


class FindableOwner extends Node2D:
	var found := false
	func is_found() -> bool:
		return found


func test_something_discoverable_reads_only_once_it_is_found() -> void:
	var owner_node := auto_free(FindableOwner.new()) as FindableOwner
	var r := _readout(owner_node)
	r.discoverable = true
	_fly_to(Vector2(10, 0))
	assert_int(_reads.size()).override_failure_message("passes unread until found").is_equal(0)
	owner_node.found = true
	_fly_to(Vector2(12, 0))
	assert_int(_reads.size()).is_equal(1)


func test_unfound_things_do_not_take_the_nearest_slot() -> void:
	var hidden_owner := auto_free(FindableOwner.new()) as FindableOwner
	var hidden := _readout(hidden_owner, Vector2(10, 0))
	hidden.discoverable = true
	var mount := _readout(null, Vector2(-100, 0))
	_fly_to(Vector2.ZERO)
	assert_object(_reads[0].readout).override_failure_message("the hidden one is nearer but cannot be read").is_same(mount)


func test_scrap_carries_a_discoverable_readout_filed_by_kind() -> void:
	var scrap := auto_free(load("res://entities/resources/Scrap1.tscn").instantiate()) as ScrapNode
	add_child(scrap)
	var r := Readout.on(scrap)
	assert_object(r).is_not_null()
	assert_bool(r.discoverable).is_true()
	assert_bool(r.readable()).override_failure_message("hidden as debris").is_false()
	scrap.reveal(false)
	assert_bool(r.readable()).override_failure_message("found by a Sweep").is_true()
	scrap.is_trophy = false
	assert_str(r.key).is_equal("scrap")
	scrap.is_trophy = true
	assert_str(r.key).is_equal("scrap_trophy")
	assert_str(r.title).is_equal("TROPHY")
	assert_str(r.rows_now()[1].label).is_equal("HITS")
	assert_bool(Readout.kind("scrap").is_empty()).override_failure_message("scrap's Record is registered").is_false()
