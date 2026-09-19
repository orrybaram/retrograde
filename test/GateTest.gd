extends GdUnitTestSuite


## Tests for the dormant Gate: what powering one costs and what it brings online, the
## Guide naming a Gate the player flies up to, the docked state the ship sits in while
## it does it, and both of those surviving a save.

const SAVE_FILE := "user://gate_test_save.cfg"
const RADIO_SCRIPT := preload("res://scripts/RobotRadio.gd")
const MSG_IDENTIFIED := "res://entities/Robot/radio/messages/gate_identified.tres"

var _gs: GameState
var _radio_persisted := true


func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	_gs.set_process(false)
	add_child(_gs)
	# Naming a Gate radios the player, and the real radio would write its show-once
	# flags to the player's own save. Hold it off for the length of the test.
	_radio_persisted = RobotRadio.persist
	RobotRadio.persist = false


func after_test() -> void:
	RobotRadio.silence()
	RobotRadio.persist = _radio_persisted
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))


func _planet(planet_name := "Veld") -> Planet:
	var planet := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	planet.name = planet_name
	planet.radius = 400.0
	planet.enable_orbiting = false
	add_child(planet)
	for grown in planet.get_ore_deposits():
		grown.free()
	return planet


func _gate(planet: Planet, cost := 600) -> Gate:
	var gate := auto_free(load("res://entities/structures/Gate.tscn").instantiate()) as Gate
	gate.power_cost = cost
	gate.enable_orbiting = false
	gate.persist = false  # keep identification out of the player's save
	planet.add_child(gate)
	return gate


## A moon on a live orbit around `planet`, the way Rook rides Veld.
func _moon(planet: Planet, distance := 20000.0, speed := 20.0) -> Planet:
	var moon := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	moon.name = "Rook"
	moon.radius = 200.0
	moon.orbital_distance = distance
	moon.orbital_speed = speed
	moon.initial_angle = PI
	moon.eccentricity = 0.04
	planet.add_child(moon)
	for grown in moon.get_ore_deposits():
		grown.free()
	return moon


## A Gate on a live orbit, holding station on a sibling if it is given one.
func _orbiting_gate(planet: Planet, follows := NodePath(), distance := 10800.0) -> Gate:
	var gate := auto_free(load("res://entities/structures/Gate.tscn").instantiate()) as Gate
	gate.persist = false
	gate.orbital_distance = distance
	gate.orbital_speed = 3.0
	gate.initial_angle_degrees = 40.0
	gate.geosync_with = follows
	planet.add_child(gate)
	return gate


## Run both orbits forward as if `seconds` had passed, without waiting them out.
func _run_orbits_for(seconds: float, moon: Planet, gate: Gate) -> void:
	moon._orbital_motion.orbital_start_time -= seconds
	moon._orbital_motion.update_orbit()
	gate._orbital_motion.update_orbit()


func _bearing_from(planet: Planet, body: Node2D) -> Vector2:
	return (body.global_position - planet.global_position).normalized()


## A radio of its own, so a test can watch what the guide would do with a request.
func _radio() -> Node:
	var radio: Node = auto_free(RADIO_SCRIPT.new())
	radio.persist = false
	return radio


func _ship() -> Ship:
	var ship := auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	add_child(ship)
	return ship


## Dock the ship the way flying in does: hand over the dockable, change state.
func _dock_at(ship: Ship, dockable: Node2D) -> void:
	ship.global_position = dockable.get_dock_position()
	ship.set_meta("pending_dockable", dockable)
	ship.state_machine.change_state(FlyingState.docked_state_for(dockable))


# --- Powering ----------------------------------------------------------------

func test_a_gate_starts_dormant_and_knows_its_planet() -> void:
	var gate := _gate(_planet("Crom"))
	assert_str(gate.save_key()).is_equal("Crom")
	assert_bool(gate.is_powered()).is_false()
	assert_int(_gs.titan_influence()).is_equal(0)


func test_powering_a_gate_spends_the_credits_and_brings_its_module_online() -> void:
	var gate := _gate(_planet("Veld"), 600)
	_gs.credits = 1000
	assert_bool(gate.power(_gs)).is_true()
	assert_int(_gs.credits).is_equal(400)
	assert_bool(gate.is_powered()).is_true()
	assert_int(_gs.titan_influence()).is_equal(1)


func test_a_gate_the_player_cannot_pay_for_stays_dormant() -> void:
	var gate := _gate(_planet("Sonder"), 2000)
	_gs.credits = 1999
	assert_bool(gate.can_afford(_gs)).is_false()
	assert_bool(gate.power(_gs)).is_false()
	assert_int(_gs.credits).is_equal(1999)
	assert_bool(gate.is_powered()).is_false()


## A Module never goes back offline, so its Gate is never charged for twice.
func test_a_powered_gate_refuses_a_second_payment() -> void:
	var gate := _gate(_planet("Roke"), 600)
	_gs.credits = 2000
	assert_bool(gate.power(_gs)).is_true()
	assert_bool(gate.power(_gs)).is_false()
	assert_int(_gs.credits).is_equal(1400)
	assert_int(_gs.titan_influence()).is_equal(1)


func test_each_planets_module_counts_once_toward_titan_influence() -> void:
	_gs.credits = 10000
	_gate(_planet("Veld"), 600).power(_gs)
	_gate(_planet("Crom"), 1200).power(_gs)
	assert_int(_gs.titan_influence()).is_equal(2)
	assert_int(_gs.credits).is_equal(8200)


## Purple is the Titan's; a dormant Gate is just dark hull out there.
func test_the_minimap_marker_takes_the_titans_color_once_powered() -> void:
	var gate := _gate(_planet("Veld"), 600)
	var marker := GateMinimapTarget.new(gate)
	assert_object(marker.get_minimap_color()).is_equal(Colors.HULL_LIGHT)
	_gs.credits = 600
	gate.power(_gs)
	assert_object(marker.get_minimap_color()).is_equal(Colors.TITAN)


func test_new_game_powers_every_module_back_down() -> void:
	var gate := _gate(_planet("Veld"), 600)
	_gs.credits = 600
	gate.power(_gs)
	_gs.reset_all_state()
	assert_dict(_gs.powered_gates).is_empty()
	assert_int(_gs.titan_influence()).is_equal(0)
	assert_bool(gate.is_powered()).is_false()


# --- Being named -------------------------------------------------------------

## A Gate nobody has flown to is a shape on the minimap and nothing else.
func test_a_gate_reads_as_unidentified_until_it_is_reached() -> void:
	var gate := _gate(_planet("Crom"))
	assert_bool(gate.is_identified()).is_false()


func test_flying_close_enough_gets_the_gate_named() -> void:
	var gate := _gate(_planet("Veld"))
	var at := gate.global_position
	# Just out of reach: nothing is named
	assert_bool(gate.identify_if_near(at + Vector2(Identifiable.RANGE + 1.0, 0.0))).is_false()
	assert_bool(gate.is_identified()).is_false()
	# Inside it, the Gate is named for good
	assert_bool(gate.identify_if_near(at + Vector2(Identifiable.RANGE - 1.0, 0.0))).is_true()
	assert_bool(gate.is_identified()).is_true()


## Reaching it is the only trigger — the guide never points at a Gate beforehand
## (docs/adr/0002), and it only ever has to be named once.
func test_reaching_a_gate_asks_the_guide_to_name_it_once() -> void:
	var gate := _gate(_planet("Veld"))
	var requested: Array[RadioConversation] = []
	var heard := func(conv: RadioConversation) -> void: requested.append(conv)
	EventBus.radio_message_requested.connect(heard)
	gate.identify_if_near(gate.global_position + Vector2(Identifiable.RANGE + 50.0, 0.0))
	assert_array(requested).is_empty()
	gate.identify_if_near(gate.global_position)
	gate.identify_if_near(gate.global_position)
	EventBus.radio_message_requested.disconnect(heard)
	assert_int(requested.size()).is_equal(1)
	assert_str(str(requested[0].id)).is_equal("gate_identified")


## The first Gate the player reaches gets the line; every later one flips silently,
## because the conversation is show-once for the whole save.
func test_only_the_first_gate_named_gets_the_guides_line() -> void:
	var conv := load(MSG_IDENTIFIED) as RadioConversation
	assert_bool(conv.once).is_true()
	assert_bool(conv.pause_game).is_false()  # the player is mid-flight when it lands
	var radio := _radio()
	assert_int(radio.request(conv)).is_equal(RadioQueue.Result.STARTED)
	assert_int(radio.request(conv)).is_equal(RadioQueue.Result.REJECTED)


## Powering is a separate thing: a named Gate is still dormant until it is paid for.
func test_naming_a_gate_leaves_its_module_offline() -> void:
	var gate := _gate(_planet("Sonder"))
	assert_bool(gate.identify()).is_true()
	assert_bool(gate.is_powered()).is_false()
	assert_int(_gs.titan_influence()).is_equal(0)


## The flag is kept against the planet in GameState, not on the node, so a Gate rebuilt
## on respawn comes back already named.
func test_a_gate_rebuilt_after_a_respawn_is_still_named() -> void:
	var planet := _planet("Roke")
	_gate(planet).identify()
	assert_bool(_gate(planet).is_identified()).is_true()


func test_new_game_makes_every_gate_unknown_again() -> void:
	var gate := _gate(_planet("Veld"))
	gate.identify()
	_gs.reset_all_state()
	assert_dict(_gs.identified_gates).is_empty()
	assert_bool(gate.is_identified()).is_false()


# --- Docked state ------------------------------------------------------------

func test_a_gate_docks_into_its_own_state_and_a_port_does_not() -> void:
	var gate := _gate(_planet("Veld"))
	assert_str(FlyingState.docked_state_for(gate)).is_equal("GateDockedState")
	var port := auto_free(load("res://entities/structures/SpacePort.tscn").instantiate()) as SpacePort
	add_child(port)
	assert_str(FlyingState.docked_state_for(port)).is_equal("LandedState")


func test_docking_at_a_gate_clamps_the_ship_to_it() -> void:
	var gate := _gate(_planet("Veld"))
	var ship := _ship()
	_dock_at(ship, gate)
	assert_str(ship.state_machine.get_current_state_name()).is_equal("GateDockedState")
	var state := ship.state_machine.current_state as GateDockedState
	assert_object(state.locked_dockable).is_same(gate)


## The cradle sits at the bottom of the ring, and that is what the ship docks to.
func test_the_dock_point_is_the_cradle_not_the_ring_centre() -> void:
	var gate := _gate(_planet("Veld"))
	gate.global_position = Vector2(500, -200)
	assert_vector(gate.get_dock_position()).is_equal_approx(
		Vector2(500, -200 + Gate.RADIUS), Vector2.ONE * 0.01)
	assert_float(gate.get_dock_distance()).is_equal(60.0)


func test_drifting_out_of_the_cradle_releases_the_ship() -> void:
	var gate := _gate(_planet("Veld"))
	var ship := _ship()
	_dock_at(ship, gate)
	var state := ship.state_machine.current_state as GateDockedState
	ship.global_position = gate.get_dock_position() + Vector2(gate.get_dock_distance() + 10.0, 0)
	state.physics_process(0.016)
	assert_str(ship.state_machine.get_current_state_name()).is_equal("FlyingState")


func test_a_gate_that_goes_away_releases_the_ship() -> void:
	var gate := _gate(_planet("Veld"))
	var ship := _ship()
	_dock_at(ship, gate)
	var state := ship.state_machine.current_state as GateDockedState
	gate.get_parent().remove_child(gate)
	gate.free()
	state.physics_process(0.016)
	assert_str(ship.state_machine.get_current_state_name()).is_equal("FlyingState")


func test_docking_without_a_gate_falls_straight_back_to_flying() -> void:
	var ship := _ship()
	ship.state_machine.change_state("GateDockedState")
	assert_str(ship.state_machine.get_current_state_name()).is_equal("FlyingState")


## Flying in names a Gate long before the cradle, but a ship that spawns docked at one
## never made the approach — so docking names it too, before the terminal takes over.
func test_docking_at_a_gate_names_it_first() -> void:
	var gate := _gate(_planet("Veld"))
	assert_bool(gate.is_identified()).is_false()
	_dock_at(_ship(), gate)
	assert_bool(gate.is_identified()).is_true()


func test_a_ship_docked_at_a_gate_is_saved_against_that_gate() -> void:
	var planet := _planet("Veld")
	var gate := _gate(planet)
	var ship := _ship()
	_dock_at(ship, gate)
	assert_str(Save._get_dockable_key_from_ship(ship)).is_equal("Veld/Gate")


# --- Saving ------------------------------------------------------------------

func test_powered_gates_round_trip_through_the_save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "credits", 42)
	cfg.save(SAVE_FILE)
	Save.save_powered_gates(PackedStringArray(["Sun/Veld", "Sun/Crom"]), SAVE_FILE)
	assert_array(Array(Save.load_powered_gates(SAVE_FILE))).contains_exactly(["Sun/Veld", "Sun/Crom"])
	cfg.load(SAVE_FILE)
	assert_int(cfg.get_value("stats", "credits")).is_equal(42)
	assert_array(Array(cfg.get_value(Save.GATE_SECTION, Save.GATE_POWERED_KEY))).contains_exactly(
		["Sun/Veld", "Sun/Crom"])


func test_gate_save_needs_an_existing_save() -> void:
	Save.save_powered_gates(PackedStringArray(["Sun/Veld"]), SAVE_FILE)
	assert_bool(FileAccess.file_exists(SAVE_FILE)).is_false()
	assert_int(Save.load_powered_gates(SAVE_FILE).size()).is_equal(0)


func test_a_save_from_before_gates_reads_as_nothing_powered() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "credits", 7)
	cfg.save(SAVE_FILE)
	assert_int(Save.load_powered_gates(SAVE_FILE).size()).is_equal(0)


func test_identified_gates_round_trip_through_the_save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "credits", 42)
	cfg.save(SAVE_FILE)
	Save.save_identified_gates(PackedStringArray(["Sun/Veld", "Sun/Crom"]), SAVE_FILE)
	assert_array(Array(Save.load_identified_gates(SAVE_FILE))).contains_exactly(
		["Sun/Veld", "Sun/Crom"])
	cfg.load(SAVE_FILE)
	assert_int(cfg.get_value("stats", "credits")).is_equal(42)
	# Naming a Gate is not powering it: the two lists are kept apart
	assert_int(Save.load_powered_gates(SAVE_FILE).size()).is_equal(0)


func test_a_save_from_before_gates_were_named_reads_as_nothing_named() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "credits", 7)
	cfg.save(SAVE_FILE)
	assert_int(Save.load_identified_gates(SAVE_FILE).size()).is_equal(0)


# --- Geosync station-keeping -------------------------------------------------


func test_a_geosync_gate_sits_on_the_line_between_the_planet_and_its_moon() -> void:
	var planet := _planet()
	var moon := _moon(planet)
	var gate := _orbiting_gate(planet, NodePath("../Rook"))
	await get_tree().process_frame  # the Gate takes the moon's orbit a frame late

	for seconds in [0.0, 11.0, 137.0, 4000.0]:
		_run_orbits_for(seconds, moon, gate)
		assert_float(_bearing_from(planet, gate).dot(_bearing_from(planet, moon))) \
			.is_equal_approx(1.0, 0.0001)
		# And still inside the moon it follows, so it is between the two of them
		assert_float(gate.global_position.distance_to(planet.global_position)) \
			.is_less(moon.global_position.distance_to(planet.global_position))


func test_a_geosync_gate_keeps_up_with_the_moon_it_follows() -> void:
	var planet := _planet()
	var moon := _moon(planet)
	var gate := _orbiting_gate(planet, NodePath("../Rook"))
	await get_tree().process_frame

	# The pair has to sweep at one rate, not at the Gate's own slower one
	assert_float(gate._orbital_motion.angular_rate()) \
		.is_equal_approx(moon._orbital_motion.get_speed_radians_per_second(), 0.000001)


func test_a_gate_with_nothing_to_follow_runs_on_its_own_orbit() -> void:
	var planet := _planet()
	var moon := _moon(planet)
	var gate := _orbiting_gate(planet)
	await get_tree().process_frame

	_run_orbits_for(137.0, moon, gate)
	assert_bool(gate._orbital_motion.is_phase_locked()).is_false()
	assert_float(_bearing_from(planet, gate).dot(_bearing_from(planet, moon))) \
		.is_less(0.999)
