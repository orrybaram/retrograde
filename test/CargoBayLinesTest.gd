extends GdUnitTestSuite

## UNIT-7's Cargo Bay lines (docs/OPENING.md §9): the first Sweep that finds scrap with no
## hold to put it in gets the need named - never the place - the hauler on Veld is named
## flatly on close approach, fitting gets a word, and the cutting tutorial waits for a
## hold to cut into.

const RADIO_SCRIPT := preload("res://scripts/RobotRadio.gd")
const SAVE_FILE := "user://cargo_bay_lines_test_save.cfg"
const Result := RadioQueue.Result

var _gs: GameState
var _requested: Array = []

func before_test() -> void:
	_gs = auto_free(GameState.new())
	add_child(_gs)
	_requested.clear()
	EventBus.radio_message_requested.connect(_on_requested)

func after_test() -> void:
	EventBus.radio_message_requested.disconnect(_on_requested)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))

func _on_requested(conv: RadioConversation) -> void:
	_requested.append(conv)

func _radio(awake := true) -> Node:
	var radio: Node = auto_free(RADIO_SCRIPT.new())
	radio.guide_awake = awake
	return radio

# --- the need ---

func test_no_need_line_before_the_cold_start() -> void:
	var radio := _radio(false)
	radio.check_swept_scrap(false)
	assert_bool(radio.is_active()).is_false()
	assert_bool(radio.has_seen(RADIO_SCRIPT.MSG_NO_HOLD.id)).override_failure_message("still owed after the wake").is_false()

func test_the_first_swept_scrap_with_no_hold_names_the_need() -> void:
	var radio := _radio()
	radio.check_swept_scrap(false)
	assert_object(radio.queue.current).is_same(RADIO_SCRIPT.MSG_NO_HOLD)

func test_the_need_is_named_once() -> void:
	var radio := _radio()
	radio.check_swept_scrap(false)
	radio.silence()
	radio.check_swept_scrap(false)
	assert_bool(radio.is_active()).is_false()

func test_no_need_line_once_the_cargo_bay_is_fitted() -> void:
	var radio := _radio()
	radio.check_swept_scrap(true)
	assert_bool(radio.is_active()).is_false()

func test_the_need_never_names_the_place() -> void:
	var text := ""
	for line in RADIO_SCRIPT.MSG_NO_HOLD.lines:
		text += line.text.to_upper() + " "
	for place in ["VELD", "HAULER", "WRECK", "CARGO BAY", "FREIGHTER"]:
		assert_str(text).override_failure_message("names %s" % place).not_contains(place)
	assert_str(text).contains("HOLD")

func test_scrap_swept_comes_from_a_live_scrap() -> void:
	var fired := [0]
	var count := func() -> void: fired[0] += 1
	EventBus.scrap_swept.connect(count)
	var scrap: ScrapNode = auto_free(ScrapNode.new())
	scrap.on_swept()
	assert_int(fired[0]).override_failure_message("not in play: pooled").is_equal(0)
	scrap.add_to_group("resource_nodes")
	scrap.on_swept()
	assert_int(fired[0]).is_equal(1)
	EventBus.scrap_swept.disconnect(count)

## Only the ship's own ring is a Sweep: SR-7's dish lights scrap across the ring when the
## power comes up, and that is nobody's search.
func test_only_a_sweep_counts_not_the_dish() -> void:
	var listener: SweepListener = auto_free(SweepListener.new())
	listener.add_to_group("sonar_listeners")
	add_child(listener)
	var pulse: SonarPulse = auto_free(SonarPulse.new())
	add_child(pulse)
	pulse.sweep = false
	pulse.send(1.0)
	await get_tree().create_timer(SonarPulse.LIFETIME + 0.1).timeout
	assert_int(listener.touched).is_equal(1)
	assert_int(listener.swept).is_equal(0)
	pulse.sweep = true
	pulse.send(1.0)
	await get_tree().create_timer(SonarPulse.LIFETIME + 0.1).timeout
	assert_int(listener.swept).is_equal(1)

func test_the_dish_pulse_is_not_a_sweep() -> void:
	var dish: CommDish = auto_free(CommDish.new())
	add_child(dish)
	dish.ping()
	var pulse := dish.get_node("Ping") as SonarPulse
	assert_bool(pulse.sweep).is_false()

class SweepListener extends Node2D:
	var touched := 0
	var swept := 0
	func sonar_point() -> Vector2:
		return global_position
	func on_sonar_touched(_strength := 1.0) -> void:
		touched += 1
	func on_swept() -> void:
		swept += 1

# --- first_scrap ---

func test_the_cutting_tutorial_waits_for_the_cargo_bay() -> void:
	var radio := _radio()
	radio.check_scrap(true, false)
	assert_bool(radio.is_active()).is_false()
	assert_bool(radio.has_seen(RADIO_SCRIPT.MSG_SCRAP.id)).is_false()
	radio.check_scrap(true, true)
	assert_object(radio.queue.current).is_same(RADIO_SCRIPT.MSG_SCRAP)

func test_fitted_is_read_from_the_game_state() -> void:
	var radio := _radio()
	add_child(radio)
	assert_bool(radio.cargo_bay_fitted()).is_false()
	_gs.progress.mark(Progress.FITTED_COMPONENTS, Components.CARGO_BAY)
	assert_bool(radio.cargo_bay_fitted()).is_true()

# --- fitting ---

func test_fitting_the_cargo_bay_gets_a_line() -> void:
	var radio := _radio()
	radio.check_fitted(Components.CARGO_BAY)
	assert_object(radio.queue.current).is_same(RADIO_SCRIPT.MSG_CARGO_BAY_FITTED)

func test_no_fitting_line_from_a_sleeping_guide() -> void:
	var radio := _radio(false)
	radio.check_fitted(Components.CARGO_BAY)
	assert_bool(radio.is_active()).is_false()

func test_the_cradle_says_what_it_fitted() -> void:
	var station := auto_free(load("res://entities/structures/SpaceStation.tscn").instantiate()) as SpaceStation
	add_child(station)
	await get_tree().process_frame
	var fitted := []
	var on_fitted := func(id: String) -> void: fitted.append(id)
	EventBus.component_fitted.connect(on_fitted)
	var was_active := Playtest.active
	var was_file := Playtest._save_file
	Playtest.active = true
	Playtest._save_file = SAVE_FILE
	_gs.cradled = PackedStringArray([Components.CARGO_BAY])
	Cradle.find(get_tree()).fit()
	Playtest.active = was_active
	Playtest._save_file = was_file
	EventBus.component_fitted.disconnect(on_fitted)
	assert_array(fitted).contains_exactly([Components.CARGO_BAY])

# --- the wreck, named ---

func _wreck() -> HaulerWreck:
	var veld := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	veld.name = "Veld"
	veld.radius = 2400.0
	veld.enable_orbiting = false
	add_child(veld)
	var wreck: HaulerWreck = auto_free(HaulerWreck.new())
	veld.add_child(wreck)
	wreck.set_process(false)  # driven by hand
	return wreck

func test_the_wreck_is_unidentified_until_close_approach() -> void:
	_gs.progress.flag(Progress.CORE_STARTED)
	var wreck := _wreck()
	assert_bool(wreck.is_identified()).is_false()
	var far := wreck.global_position + Vector2(Identifiable.RANGE * 2.0, 0)
	assert_bool(wreck.identify_if_near(far)).is_false()
	assert_bool(wreck.is_identified()).is_false()
	assert_array(_requested).is_empty()
	var near := wreck.global_position + Vector2(Identifiable.RANGE * 0.5, 0)
	assert_bool(wreck.identify_if_near(near)).is_true()
	assert_bool(wreck.is_identified()).is_true()
	assert_array(_requested).contains_exactly([HaulerWreck.MSG_IDENTIFIED])

func test_it_is_named_only_once() -> void:
	_gs.progress.flag(Progress.CORE_STARTED)
	var wreck := _wreck()
	wreck.identify_if_near(wreck.global_position)
	assert_bool(wreck.identify_if_near(wreck.global_position)).is_false()
	assert_int(_requested.size()).is_equal(1)

func test_nobody_names_it_before_the_cold_start() -> void:
	var wreck := _wreck()
	assert_bool(wreck.identify_if_near(wreck.global_position)).is_false()
	assert_bool(wreck.is_identified()).override_failure_message("still to be named once UNIT-7 is up").is_false()
	assert_array(_requested).is_empty()

func test_it_is_named_flatly() -> void:
	assert_str(HaulerWreck.NAME).is_equal("HAULER, DOWN")
	assert_str(HaulerWreck.MSG_IDENTIFIED.lines[0].text).contains(HaulerWreck.NAME)
	assert_bool(HaulerWreck.MSG_IDENTIFIED.pause_game).override_failure_message("named in flight").is_false()

## Naming the wreck marks it in the ledger once, and a continue brings the name back.
func test_the_name_comes_back_on_a_continue() -> void:
	_gs.progress.flag(Progress.CORE_STARTED)
	var wreck := _wreck()
	wreck.identify_if_near(wreck.global_position)
	_gs.progress = _gs.progress.resumed()
	assert_array(Array(_gs.progress.list(Progress.IDENTIFIED_WRECKS))).contains_exactly([wreck.save_key()])
	assert_bool(wreck.is_identified()).is_true()

## Named in flight, the wreck is written into the save where saves before the ledger kept it.
func test_named_wrecks_round_trip_through_the_save_file() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "stores", 0)
	cfg.save(SAVE_FILE)
	Progress.new(Progress.FileStore.new(SAVE_FILE)).mark(Progress.IDENTIFIED_WRECKS, "hauler_veld")
	cfg.load(SAVE_FILE)
	assert_array(Array(cfg.get_value("finds", "identified_wrecks"))).contains_exactly(["hauler_veld"])
	var ledger := Progress.new(Progress.FileStore.new(SAVE_FILE)).resumed()
	assert_bool(ledger.holds(Progress.IDENTIFIED_WRECKS, "hauler_veld")).is_true()

func test_a_new_game_forgets_the_name() -> void:
	_gs.progress.mark(Progress.IDENTIFIED_WRECKS, "hauler_veld")
	_gs.reset_all_state()
	assert_bool(_gs.progress.holds(Progress.IDENTIFIED_WRECKS, "hauler_veld")).is_false()

# --- the lines ---

func test_the_lines_are_valid() -> void:
	for conv in [RADIO_SCRIPT.MSG_NO_HOLD, RADIO_SCRIPT.MSG_CARGO_BAY_FITTED, HaulerWreck.MSG_IDENTIFIED]:
		assert_bool(conv.once).override_failure_message(String(conv.id)).is_true()
		assert_bool(conv.lines.is_empty()).is_false()
		for line in conv.lines:
			assert_bool(RobotFaces.has_face(line.expression)).override_failure_message("%s: %s" % [conv.id, line.expression]).is_true()
			assert_bool(line.glitch).override_failure_message("%s: sincere, no glitch" % conv.id).is_false()
			assert_bool(line.is_confirm()).is_false()
	assert_bool(RADIO_SCRIPT.MSG_NO_HOLD.pause_game).override_failure_message("a tutorial, like the cutting one").is_true()
