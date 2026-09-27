extends GdUnitTestSuite

## The Cargo Bay buried on Veld (docs/OPENING.md §9): a hauler wreck with the first
## Component standing Lug-up in it, dead to the Sweep until SR-7's cold start and answering
## from far off after it, too deep for the Aux to pull and torn out only by the Burn.

const VELD_RADIUS := 2400.0
const OUTWARD := Vector2.UP

var _gs: GameState

func before_test() -> void:
	_gs = auto_free(GameState.new())
	add_child(_gs)

func _bay() -> Freight:
	var f: Freight = auto_free(Freight.new())
	Components.apply(f, Components.CARGO_BAY)
	add_child(f)
	return f

func _veld() -> Planet:
	var planet := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	planet.radius = VELD_RADIUS
	planet.planet_type = Planet.PlanetType.ICE
	planet.enable_orbiting = false
	add_child(planet)
	return planet

func _ground() -> Node2D:
	var n: Node2D = auto_free(Node2D.new())
	add_child(n)
	return n

func _ship() -> Ship:
	return auto_free(Ship.new())

## Pull on `f` straight out of the ground for `seconds`, Burn lit or not. True if it tore free.
func _pull(f: Freight, seconds: float, burn: bool) -> bool:
	var boost := _ship().boost_power_multiplier if burn else 1.0
	var force := FlyingState.pull_force(OUTWARD, 1.0, OUTWARD, boost)
	var dt := 1.0 / 60.0
	for i in int(seconds / dt):
		if f.pull(force, dt):
			return true
	return false

# --- the piece ---

func test_the_cargo_bay_is_a_component_not_a_section() -> void:
	var f := _bay()
	assert_str(f.component).is_equal(Components.CARGO_BAY)
	assert_str(f.section).is_equal("")
	assert_str(f.label).is_equal("CARGO BAY")
	assert_object(Mount.for_section(get_tree(), f.section)).is_null()

func test_it_is_heavier_than_any_section() -> void:
	for id in Sections.DATA:
		assert_float(_bay().mass).is_greater(Sections.DATA[id]["mass"])

# --- the pull ---

func test_the_aux_alone_never_tears_it_free() -> void:
	var f := _bay()
	f.bury_in(_ground(), Components.pull_threshold(Components.CARGO_BAY))
	assert_float(f.pull_threshold).is_greater(1.0)
	assert_bool(_pull(f, 30.0, false)).override_failure_message("the Aux strains; the ground holds").is_false()
	assert_float(f.pull_progress).is_equal(0.0)
	assert_bool(f.is_buried()).is_true()

func test_the_burn_tears_it_free() -> void:
	var f := _bay()
	f.bury_in(_ground(), Components.pull_threshold(Components.CARGO_BAY))
	assert_bool(_pull(f, f.pull_time + 0.1, true)).is_true()

func test_the_burn_does_it_even_a_little_off_straight_out() -> void:
	var f := _bay()
	f.bury_in(_ground(), Components.pull_threshold(Components.CARGO_BAY))
	var heading := OUTWARD.rotated(deg_to_rad(30.0))
	var force := FlyingState.pull_force(heading, 1.0, OUTWARD, _ship().boost_power_multiplier)
	assert_float(force).is_greater_equal(f.pull_threshold)

func test_the_aux_lifts_it_off_veld() -> void:
	# Veld's pull is a force on the whole ship, whatever it carries: the Aux's thrust beats
	# it at the ground, so the ship climbs with the Cargo Bay on its nose, if slowly
	var veld := _veld()
	var at_ground := veld.mass * veld.gravitational_constant / (VELD_RADIUS * VELD_RADIUS)
	assert_float(_ship().thrust_power).is_greater(at_ground * 1.2)

# --- the Sweep ---

func test_dead_to_the_sweep_until_the_cold_start() -> void:
	var f := _bay()
	assert_bool(f.answers_sweep()).is_false()
	assert_float(f.answer_clarity(10.0, SonarPulse.END_RADIUS)).override_failure_message("not even inside the ring").is_equal(0.0)
	_gs.core_started = true
	assert_bool(f.answers_sweep()).is_true()
	assert_float(f.answer_clarity(10.0, SonarPulse.END_RADIUS)).is_equal(1.0)

func test_after_the_cold_start_it_answers_from_long_range() -> void:
	_gs.core_started = true
	var f := _bay()
	var ring := SonarPulse.END_RADIUS
	assert_float(f.answer_range).is_greater(ring * 10.0)
	var near := f.answer_clarity(ring * 2.0, ring)
	var far := f.answer_clarity(f.answer_range * 0.95, ring)
	assert_float(near).is_greater(far)
	assert_float(far).override_failure_message("faint at the edge, but there").is_greater(0.0)
	assert_float(f.answer_clarity(f.answer_range + 1.0, ring)).is_equal(0.0)

func test_ordinary_freight_answers_only_inside_the_ring() -> void:
	var f: Freight = auto_free(Freight.new())
	add_child(f)
	assert_float(f.answer_clarity(100.0, SonarPulse.END_RADIUS)).is_equal(1.0)
	assert_float(f.answer_clarity(SonarPulse.END_RADIUS + 1.0, SonarPulse.END_RADIUS)).is_equal(0.0)

func test_a_long_answer_comes_back_to_the_ship() -> void:
	var s := SonarPulse.long_answer_strength(3000.0)
	assert_float(SonarPulse.END_RADIUS * s * SonarEcho.ANSWER_REACH).is_greater_equal(3000.0)

func test_a_faint_answer_is_broken_and_a_clear_one_whole() -> void:
	var f := _bay()
	f.on_sonar_touched(1.0, 1.0)
	f.on_sonar_touched(10.0, 0.3)
	var echoes: Array = f._visual.get_children().filter(func(c): return c is SonarEcho)
	assert_bool(echoes[0].arcs.is_empty()).is_true()
	var kept: int = echoes[1].arcs.count(true)
	assert_int(kept).is_greater(0)
	assert_int(kept).is_less(SonarEcho.BROKEN_ARCS)
	assert_float(echoes[1].max_alpha).is_less(echoes[0].max_alpha)
	assert_float(echoes[1].lifetime).is_less_equal(SonarPulse.LIFETIME * SonarEcho.FAR_ANSWER_LIFETIME)

func test_a_sweep_out_of_reach_gets_an_answer_only_after_the_cold_start() -> void:
	var pulse: SonarPulse = auto_free(SonarPulse.new())
	add_child(pulse)
	var f := _bay()
	f.global_position = Vector2(2000, 0)
	pulse.send(1.0)
	await get_tree().create_timer(SonarPulse.LIFETIME + 0.2).timeout
	assert_int(f._visual.get_children().filter(func(c): return c is SonarEcho).size()).is_equal(0)
	_gs.core_started = true
	pulse.send(1.0)
	await get_tree().create_timer(SonarPulse.LIFETIME + 0.2).timeout
	var echoes: Array = f._visual.get_children().filter(func(c): return c is SonarEcho)
	assert_int(echoes.size()).is_equal(1)
	assert_bool(echoes[0].arcs.is_empty()).override_failure_message("from past the ring: broken").is_false()

# --- the wreck ---

func test_the_wreck_buries_the_cargo_bay_lug_up_in_veld() -> void:
	var veld := _veld()
	var wreck: HaulerWreck = auto_free(HaulerWreck.new())
	veld.add_child(wreck)
	wreck.ensure_cargo_bay()
	var f := wreck.find_piece()
	assert_object(f).is_not_null()
	auto_free(f)
	assert_bool(f.is_buried()).is_true()
	assert_float(f.pull_threshold).is_equal(Components.pull_threshold(Components.CARGO_BAY))
	assert_object(f.lodged_in).is_same(veld)
	var ground := Mount.ground_radius(veld)
	var lug_height := f.lug_global().distance_to(veld.global_position) - ground
	assert_float(lug_height).override_failure_message("the Lug stands out of the ground").is_between(HaulerWreck.BAY_EXPOSED - 12.0, HaulerWreck.BAY_EXPOSED + 1.0)
	assert_float(f.global_position.distance_to(veld.global_position)).override_failure_message("the rest is in it").is_less(ground + 20.0)
	assert_float(f.global_position.distance_to(wreck.global_position)).is_less(HaulerWreck.BAY_EXPOSED)
	# Once there, it is never put there twice
	wreck.ensure_cargo_bay()
	var count := get_tree().get_nodes_in_group("freight").filter(func(n): return n is Freight and n.component == Components.CARGO_BAY).size()
	assert_int(count).is_equal(1)

func test_a_saved_cargo_bay_keeps_what_it_is() -> void:
	var f := _bay()
	f.bury_in(_ground(), 5.0)
	var g: Freight = auto_free(Freight.from_row(self, f.to_row()))
	assert_str(g.component).is_equal(Components.CARGO_BAY)
	assert_float(g.mass).is_equal(f.mass)
	assert_float(g.pull_time).is_equal(f.pull_time)
	assert_bool(g.is_buried()).is_true()
