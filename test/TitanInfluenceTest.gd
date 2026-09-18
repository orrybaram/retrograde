extends GdUnitTestSuite

## Tests for what Titan Influence leaks into the rest of the game: the floor it puts
## under the dashboard glitch, and the point at which it starts showing on the guide's
## face. Nothing here is gameplay — it is all readouts and paint.


const DASHBOARD_HOME := Vector2(2, 496)
const PLANETS := ["Veld", "Crom", "Sonder", "Roke", "TERRA-0"]


func before_test() -> void:
	VoidZone.reset()


## One GameState per test: the glitch finds it through the `game_state` group, so a
## second one would never be seen.
func _game_state() -> GameState:
	var gs := auto_free(GameState.new()) as GameState
	gs.set_process(false)
	add_child(gs)
	return gs


## Brings Modules online until `influence` of them are.
func _power_up_to(gs: GameState, influence: int) -> void:
	for planet in PLANETS.slice(0, influence):
		gs.mark_gate_powered(planet)


## A HudGlitch over a stand-in dashboard. It reads whichever GameState is in the tree,
## so make that first.
func _glitch_over_a_dashboard() -> HudGlitch:
	var hud := auto_free(Control.new()) as Control
	var dashboard := Control.new()
	dashboard.name = "DashboardAnchor"
	dashboard.position = DASHBOARD_HOME
	hud.add_child(dashboard)
	add_child(hud)

	var glitch := HudGlitch.new()
	glitch.set_process(false)  # driven a frame at a time by the tests
	hud.add_child(glitch)
	return glitch


## Runs `frames` of the glitch and reports how many of them the dashboard was dark for.
## Every frame it is not dark it has to be sitting at the dim `influence` calls for, and
## every frame it has to be where the layout put it — the Titan never moves the panel.
func _run_frames(glitch: HudGlitch, frames: int, influence: int) -> int:
	var lit := lerpf(1.0, 0.55, TitanInfluence.baseline_glitch(influence))
	var dark := 0
	for frame in frames:
		glitch._process(1.0 / 60.0)
		var alpha := glitch.dashboard.modulate.a
		if alpha <= 0.0:
			dark += 1
		else:
			assert_float(alpha).is_equal_approx(lit, 0.0001)
		assert_vector(glitch.dashboard.position).is_equal(DASHBOARD_HOME)
	return dark


func _seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# --- The dashboard baseline ---------------------------------------------------

func test_nothing_is_wrong_with_the_hud_before_the_first_gate() -> void:
	assert_float(TitanInfluence.baseline_glitch(0)).is_equal(0.0)


func test_every_module_that_comes_online_raises_the_baseline() -> void:
	var previous := TitanInfluence.baseline_glitch(0)
	for influence in range(1, TitanInfluence.MODULES + 1):
		var level := TitanInfluence.baseline_glitch(influence)
		assert_float(level).is_greater(previous)
		previous = level
	assert_float(previous).is_equal_approx(TitanInfluence.MAX_BASELINE_GLITCH, 0.0001)


## Past ROT_THRESHOLD the characters start rotting into line noise. The Titan never
## gets there on its own: with all five Modules online the readouts dim and cut, but
## they still say what they say, and the player can still fly on them.
func test_the_dashboard_is_still_readable_with_all_five_modules_online() -> void:
	var full := TitanInfluence.baseline_glitch(TitanInfluence.MODULES)
	assert_float(full).is_greater(0.0)
	assert_float(full).is_less(HudGlitch.ROT_THRESHOLD)


func test_the_baseline_stops_at_the_last_module() -> void:
	assert_float(TitanInfluence.baseline_glitch(9)).is_equal(TitanInfluence.MAX_BASELINE_GLITCH)
	assert_float(TitanInfluence.baseline_glitch(-1)).is_equal(0.0)


## The dim alone barely separates one Module from two, so the blink is what actually
## carries each Gate onto the HUD: same blink, steadily more often.
func test_the_dashboard_never_blinks_until_the_first_module_is_online() -> void:
	assert_bool(is_inf(TitanInfluence.blink_gap(0))).is_true()
	assert_bool(is_inf(TitanInfluence.blink_gap(-1))).is_true()
	assert_bool(is_inf(TitanInfluence.blink_gap(1))).is_false()


func test_every_module_that_comes_online_blinks_the_dashboard_more_often() -> void:
	var previous := TitanInfluence.blink_gap(1)
	assert_float(previous).is_equal(TitanInfluence.BLINK_GAP_FIRST)
	for influence in range(2, TitanInfluence.MODULES + 1):
		var gap := TitanInfluence.blink_gap(influence)
		assert_float(gap).is_less(previous)
		previous = gap
	assert_float(previous).is_equal(TitanInfluence.BLINK_GAP_FULL)
	assert_float(TitanInfluence.blink_gap(9)).is_equal(TitanInfluence.BLINK_GAP_FULL)


## Even at five Modules the panel is lit far more than it is dark, or the player
## couldn't fly on it.
func test_the_dashboard_is_lit_between_blinks_even_at_five_modules() -> void:
	var duty := TitanInfluence.BLINK_SEC / TitanInfluence.blink_gap(TitanInfluence.MODULES)
	assert_float(duty).is_less(0.05)


func test_the_hud_reads_its_baseline_off_the_modules_that_are_online() -> void:
	var gs := _game_state()
	var glitch := auto_free(HudGlitch.new()) as HudGlitch
	glitch.set_process(false)
	add_child(glitch)

	assert_float(glitch.severity()).is_equal(0.0)
	gs.mark_gate_powered("Veld")
	assert_float(glitch.baseline()).is_equal_approx(TitanInfluence.baseline_glitch(1), 0.0001)
	assert_float(glitch.severity()).is_equal_approx(TitanInfluence.baseline_glitch(1), 0.0001)
	gs.mark_gate_powered("Crom")
	assert_float(glitch.severity()).is_greater(TitanInfluence.baseline_glitch(1))


## Before the first Gate the glitch is inert, exactly as it has always been: full
## brightness, every frame, and the panel where the layout left it.
func test_a_hud_with_nothing_online_is_left_completely_alone() -> void:
	_game_state()
	var glitch := _glitch_over_a_dashboard()
	assert_int(_run_frames(glitch, 600, 0)).is_equal(0)
	assert_float(glitch.dashboard.modulate.a).is_equal(1.0)


## Ten seconds with all five Modules online: the panel blinks several times and is
## dimmed the rest of the time, but it is lit and readable for nearly all of it.
func test_with_every_module_online_the_dashboard_blinks_but_stays_readable() -> void:
	_power_up_to(_game_state(), TitanInfluence.MODULES)
	var glitch := _glitch_over_a_dashboard()
	var dark := _run_frames(glitch, 600, TitanInfluence.MODULES)
	assert_int(dark).is_greater(0)
	assert_int(dark).is_less(60)


## And one Module online blinks it far less than five do: the same HUD, a minute at a
## time, as the player powers the rest of the Gates.
func test_the_hud_gets_louder_as_more_modules_come_online() -> void:
	var gs := _game_state()
	var glitch := _glitch_over_a_dashboard()
	_power_up_to(gs, 1)
	var one := _run_frames(glitch, 3600, 1)
	_power_up_to(gs, TitanInfluence.MODULES)
	var five := _run_frames(glitch, 3600, TitanInfluence.MODULES)
	assert_int(one).is_greater(0)
	assert_int(five).is_greater(one)


## A new game takes every Module back offline, and the dashboard has to come back with
## it — lit again, even if the Titan was mid-blink when the save was wiped.
func test_a_new_game_hands_the_dashboard_back_clean() -> void:
	var gs := _game_state()
	var glitch := _glitch_over_a_dashboard()
	_power_up_to(gs, TitanInfluence.MODULES)
	_run_frames(glitch, 600, TitanInfluence.MODULES)
	gs.reset_all_state()
	assert_int(_run_frames(glitch, 120, 0)).is_equal(0)
	assert_float(glitch.dashboard.modulate.a).is_equal(1.0)


## The floor is a floor: a hull hit still spikes straight over it.
func test_a_hull_hit_still_wins_over_the_baseline() -> void:
	_power_up_to(_game_state(), TitanInfluence.MODULES)
	var glitch := auto_free(HudGlitch.new()) as HudGlitch
	glitch.set_process(false)
	add_child(glitch)

	glitch.hit(0.9)
	assert_float(glitch.severity()).is_equal_approx(0.9, 0.0001)


# --- The Titan on the guide's face --------------------------------------------

func test_the_titan_stays_off_the_guides_face_below_three_modules() -> void:
	var rng := _seeded(7)
	for influence in TitanInfluence.FACE_MIN_INFLUENCE:
		assert_bool(TitanInfluence.bleeds_into_the_guide(influence)).is_false()
		for roll in 200:
			assert_bool(TitanInfluence.flashes_titan_face(influence, rng)).is_false()


func test_the_titan_reaches_the_guide_from_three_modules_on() -> void:
	for influence in range(TitanInfluence.FACE_MIN_INFLUENCE, TitanInfluence.MODULES + 1):
		assert_bool(TitanInfluence.bleeds_into_the_guide(influence)).is_true()
	var rng := _seeded(11)
	var flashed := false
	for roll in 50:
		flashed = flashed or TitanInfluence.flashes_titan_face(TitanInfluence.FACE_MIN_INFLUENCE, rng)
	assert_bool(flashed).is_true()


func test_about_every_second_line_flashes() -> void:
	var rng := _seeded(12345)
	var flashes := 0
	for roll in 1000:
		if TitanInfluence.flashes_titan_face(TitanInfluence.MODULES, rng):
			flashes += 1
	assert_int(flashes).is_between(400, 600)


## The face keeps its shape and its expression; only the color is the Titan's, and
## only for a moment.
func test_a_flash_paints_the_face_purple_and_then_hands_it_back() -> void:
	var robot := auto_free(RobotView.new()) as RobotView
	assert_object(robot._face_color()).is_equal(Colors.PRIMARY)
	robot.titan_flash()
	assert_object(robot._face_color()).is_equal(Colors.TITAN)
	robot._process(TitanInfluence.FACE_FLASH_SEC + 0.01)
	assert_object(robot._face_color()).is_equal(Colors.PRIMARY)


func test_a_flash_is_over_in_a_frame_or_two() -> void:
	assert_float(TitanInfluence.FACE_FLASH_SEC).is_less_equal(4.0 / 60.0)
	var robot := auto_free(RobotView.new()) as RobotView
	robot.titan_flash()
	robot._process(1.0 / 60.0)
	assert_object(robot._face_color()).is_equal(Colors.TITAN)
