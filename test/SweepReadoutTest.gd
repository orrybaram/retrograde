extends GdUnitTestSuite

## A SweepReadout is read by the ship's own Sweep, as deep as the ring is strong, and the
## read holds in the ledger (docs/SWEEP.md §10).

var _gs: GameState
var _reads: Array = []

func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	add_child(_gs)
	_reads.clear()
	EventBus.readout_swept.connect(_on_read)

func after_test() -> void:
	EventBus.readout_swept.disconnect(_on_read)

func _on_read(readout: Node, tier: int, rows: Array) -> void:
	_reads.append({"readout": readout, "tier": tier, "rows": rows})

func _readout(owner_node: Node = null) -> SweepReadout:
	var r := SweepReadout.new()
	r.key = "test_thing"
	r.heading = "MOUNT"
	r.title = "TEST"
	r.rows = [ReadoutRow.make("STATE", "EMPTY"), ReadoutRow.make("EDGE", "TORCH CUT", 2),
		ReadoutRow.make("FRACTURE", "NONE", 3)]
	var parent: Node = owner_node if owner_node else auto_free(Node2D.new())
	if parent.get_parent() == null:
		add_child(parent)
	parent.add_child(r)
	return r

class LiveOwner extends Node2D:
	var seated := false
	func readout_rows(tier: int) -> Array[ReadoutRow]:
		var out: Array[ReadoutRow] = [ReadoutRow.make("STATE", "SEATED" if seated else "EMPTY")]
		if tier >= 2:
			out.append(ReadoutRow.make("DEPTH", str(tier), 2))
		return out


func test_a_tap_reads_one_tier_and_each_charge_one_more() -> void:
	assert_int(SweepReadout.tier_for(1.0)).is_equal(1)
	assert_int(SweepReadout.tier_for(SonarPulse.strength_for(1.4))).is_equal(1)
	assert_int(SweepReadout.tier_for(SonarPulse.strength_for(SonarPulse.CHARGE_TIME))).is_equal(2)
	assert_int(SweepReadout.tier_for(SonarPulse.strength_for(SonarPulse.CHARGE_TIME * 2))).is_equal(3)
	assert_int(SweepReadout.tier_for(10.0)).override_failure_message("no tier past the last").is_equal(SweepReadout.MAX_TIER)


func test_rows_show_only_their_tier_and_under() -> void:
	var r := _readout()
	assert_int(r.rows_for(1).size()).is_equal(1)
	assert_int(r.rows_for(2).size()).is_equal(2)
	assert_int(r.rows_for(3).size()).is_equal(3)


func test_an_owner_with_live_state_gives_the_rows() -> void:
	var owner_node := auto_free(LiveOwner.new()) as LiveOwner
	var r := _readout(owner_node)
	assert_str(r.rows_for(1)[0].value).is_equal("EMPTY")
	owner_node.seated = true
	assert_str(r.rows_for(1)[0].value).is_equal("SEATED")
	assert_int(r.rows_for(2).size()).is_equal(2)


func test_the_sweep_reads_it_as_deep_as_the_ring_that_touched_it() -> void:
	var r := _readout()
	r.on_sonar_touched(SonarPulse.strength_for(SonarPulse.CHARGE_TIME))
	r.on_swept()
	assert_int(_reads.size()).is_equal(1)
	assert_object(_reads[0].readout).is_same(r)
	assert_int(_reads[0].tier).is_equal(2)
	assert_int(_reads[0].rows.size()).is_equal(2)


func test_a_ring_that_is_not_a_sweep_reads_nothing() -> void:
	var r := _readout()
	r.on_sonar_touched(3.0)  # SR-7's dish: touched, never swept
	assert_int(_reads.size()).is_equal(0)
	assert_bool(r.is_read()).is_false()


func test_a_read_holds_in_the_ledger() -> void:
	var r := _readout()
	assert_bool(r.is_read()).is_false()
	r.read(1.0)
	assert_bool(r.is_read()).is_true()
	assert_bool(_gs.progress.holds(Progress.SWEPT_READOUTS, "test_thing")).is_true()


func test_it_listens_for_rings_where_it_is() -> void:
	var r := _readout()
	r.global_position = Vector2(120, -40)
	assert_bool(r.is_in_group("sonar_listeners")).is_true()
	assert_vector(r.sonar_point()).is_equal(Vector2(120, -40))
	assert_object(SweepReadout.on(r.get_parent())).is_same(r)


func test_every_mount_on_sr7_carries_one() -> void:
	var station := auto_free(load("res://entities/structures/SpaceStation.tscn").instantiate()) as Node2D
	add_child(station)
	await get_tree().process_frame
	for id in [Sections.FUEL_TANK, Sections.SOLAR_ARRAY, Sections.DORSAL_ARM]:
		var m := Mount.for_section(get_tree(), id)
		var r := SweepReadout.on(m)
		assert_object(r).override_failure_message("%s's Mount has a readout" % id).is_not_null()
		assert_str(r.title).is_equal(Sections.DATA[id]["label"])
	var fuel := SweepReadout.on(Mount.for_section(get_tree(), Sections.FUEL_TANK))
	var rows := fuel.rows_for(1)
	assert_str(rows[0].value).is_equal("EMPTY")
	assert_str(rows[1].label).is_equal("SECTION")
	Mount.for_section(get_tree(), Sections.FUEL_TANK).seated = true
	rows = fuel.rows_for(1)
	assert_str(rows[0].value).is_equal("SEATED")
	assert_int(rows.size()).override_failure_message("nothing to mark once it is home").is_equal(1)
	Freight.clear_all(get_tree())


func test_a_deeper_read_is_kept_as_deep_as_it_went() -> void:
	var r := _readout()
	assert_int(r.depth_read()).is_equal(0)
	r.read(1.0)
	assert_int(r.depth_read()).is_equal(1)
	r.read(3.0)
	assert_int(r.depth_read()).is_equal(3)
	r.read(1.0)
	assert_int(r.depth_read()).override_failure_message("a shallow read takes nothing back").is_equal(3)
	assert_bool(_gs.progress.holds(Progress.SWEPT_READOUTS, "test_thing#2")).is_true()


class KeyedOwner extends Node2D:
	func save_key() -> String:
		return "HomeSystem/Veld"


func test_under_an_owner_with_a_save_key_the_key_is_a_prefix() -> void:
	var r := _readout(auto_free(KeyedOwner.new()))
	r.key = "gate"
	assert_str(r.ledger_key()).is_equal("gate:HomeSystem/Veld")
	r.read(1.0)
	assert_bool(_gs.progress.holds(Progress.SWEPT_READOUTS, "gate:HomeSystem/Veld")).is_true()


func test_an_undecipherable_thing_reads_as_noise_of_the_same_shape() -> void:
	var r := _readout()
	r.undecipherable = true
	assert_str(r.shown_heading()).is_not_equal("MOUNT")
	assert_int(r.shown_heading().length()).is_equal("MOUNT".length())
	assert_str(r.shown_heading()).override_failure_message("the same noise every time").is_equal(r.shown_heading())
	var rows := r.shown_rows(2)
	assert_int(rows.size()).is_equal(2)
	assert_str(rows[1].value).is_not_equal("TORCH CUT")
	assert_str(rows[1].value[5]).override_failure_message("spaces survive").is_equal(" ")
	for c in rows[0].label:
		assert_bool(RobotFaces.GLITCH_CHARS.contains(c)).is_true()
	r.on_sonar_touched(1.0)
	r.on_swept()
	assert_str(_reads[0].rows[0].value).override_failure_message("what goes out is the noise").is_not_equal("EMPTY")
	assert_bool(r.is_read()).override_failure_message("it was still read").is_true()


func test_gates_carry_an_undecipherable_one() -> void:
	var gate := auto_free(load("res://entities/structures/Gate.tscn").instantiate()) as Gate
	var r := SweepReadout.on(gate)
	assert_object(r).is_not_null()
	assert_bool(r.undecipherable).is_true()
	assert_str(r.key).is_equal("gate")
