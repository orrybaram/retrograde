extends GdUnitTestSuite

## The hull warnings, from the thresholds outward: the level everything reads from,
## the escalation from a nervous bar to a banner, and the glitch that only a hit is
## allowed to fire. The point of pinning these is that a player must always be able
## to READ the hull bar — the corruption belongs to the moment of impact, not to
## being low, or the warning hides the thing it is warning about.


func test_hull_levels_step_at_the_documented_ratios() -> void:
	assert_int(LowHullEffect.level_for(100.0, 100.0)).is_equal(LowHullEffect.Level.OK)
	assert_int(LowHullEffect.level_for(36.0, 100.0)).is_equal(LowHullEffect.Level.OK)
	# The boundaries themselves are already a warning.
	assert_int(LowHullEffect.level_for(35.0, 100.0)).is_equal(LowHullEffect.Level.LOW)
	assert_int(LowHullEffect.level_for(16.0, 100.0)).is_equal(LowHullEffect.Level.LOW)
	assert_int(LowHullEffect.level_for(15.0, 100.0)).is_equal(LowHullEffect.Level.CRITICAL)
	assert_int(LowHullEffect.level_for(0.0, 100.0)).is_equal(LowHullEffect.Level.CRITICAL)


func test_hull_levels_scale_with_an_upgraded_hull() -> void:
	# An upgrade must not quietly move the warning: the levels are ratios, not HP.
	assert_int(LowHullEffect.level_for(71.0, 200.0)).is_equal(LowHullEffect.Level.OK)
	assert_int(LowHullEffect.level_for(70.0, 200.0)).is_equal(LowHullEffect.Level.LOW)  # exactly 35%
	assert_int(LowHullEffect.level_for(30.0, 200.0)).is_equal(LowHullEffect.Level.CRITICAL)


func test_a_ship_with_no_hull_at_all_is_not_an_alarm() -> void:
	# Guards the div-by-zero path before a ship has been configured.
	assert_int(LowHullEffect.level_for(0.0, 0.0)).is_equal(LowHullEffect.Level.OK)


func test_the_warning_escalates_from_breach_to_critical() -> void:
	var warning: HullWarning = auto_free(HullWarning.new())
	add_child(warning)

	warning._on_hull_changed(100.0, 100.0)
	assert_bool(warning.visible).is_false()

	warning._on_hull_changed(30.0, 100.0)
	assert_bool(warning.visible).is_true()
	assert_str(warning._label.text).contains("B R E A C H")

	warning._on_hull_changed(10.0, 100.0)
	assert_str(warning._label.text).contains("C R I T I C A L")

	# Repaired: the banner has to leave, not sit there blinking at a full hull.
	warning._on_hull_changed(100.0, 100.0)
	assert_bool(warning.visible).is_false()


func test_a_destroyed_ship_does_not_get_a_hull_banner() -> void:
	# At zero the explosion is the warning; a banner over the wreck is noise.
	var warning: HullWarning = auto_free(HullWarning.new())
	add_child(warning)
	warning._on_hull_changed(0.0, 100.0)
	assert_bool(warning.visible).is_false()


func test_the_bar_only_animates_when_there_is_something_to_animate() -> void:
	var bar: HullSegmentBar = auto_free(HullSegmentBar.new())
	add_child(bar)

	bar.set_value(100.0, 100.0)
	assert_bool(bar.is_processing()).is_false()

	bar.set_value(20.0, 100.0)
	assert_bool(bar.is_processing()).is_true()

	bar.set_value(100.0, 100.0)
	assert_bool(bar.is_processing()).is_false()


func test_a_hit_flashes_the_bar_even_at_full_hull() -> void:
	var bar: HullSegmentBar = auto_free(HullSegmentBar.new())
	add_child(bar)
	bar.set_value(100.0, 100.0)

	EventBus.ship_damaged.emit(5.0, 0.95)
	assert_float(bar._flash).is_greater(0.0)
	assert_bool(bar.is_processing()).is_true()

	# And it burns off on its own rather than latching.
	bar._process(HullSegmentBar.HIT_FLASH + 0.01)
	assert_float(bar._flash).is_equal(0.0)
	assert_bool(bar.is_processing()).is_false()


func test_only_a_hit_glitches_the_readouts_never_a_low_hull() -> void:
	var glitch: HudGlitch = auto_free(HudGlitch.new())
	add_child(glitch)

	# Sitting at one block of hull: the numbers stay clean so they can be read.
	EventBus.ship_hull_changed.emit(5.0, 100.0)
	assert_float(glitch.severity()).is_equal(0.0)

	# Taking the hit is what scrambles them.
	EventBus.ship_damaged.emit(20.0, 0.05)
	assert_float(glitch.severity()).is_greater(0.0)


func test_a_harder_hit_glitches_harder_and_the_last_block_hurts_most() -> void:
	var graze: HudGlitch = auto_free(HudGlitch.new())
	var wound: HudGlitch = auto_free(HudGlitch.new())
	var dying: HudGlitch = auto_free(HudGlitch.new())
	add_child(graze)
	add_child(wound)
	add_child(dying)

	graze._on_ship_damaged(2.0, 0.9)
	wound._on_ship_damaged(20.0, 0.9)
	dying._on_ship_damaged(20.0, 0.05)

	assert_float(wound.severity()).is_greater(graze.severity())
	assert_float(dying.severity()).is_greater(wound.severity())
	assert_float(dying.severity()).is_less_equal(1.0)


func test_the_glitch_shakes_a_hit_off_by_itself() -> void:
	var glitch: HudGlitch = auto_free(HudGlitch.new())
	add_child(glitch)
	glitch.hit(1.0)

	# No dashboard bound in a test, so drive the decay the way _process would.
	for i in 20:
		glitch._hit = maxf(glitch._hit - HudGlitch.HIT_DECAY * 0.05, 0.0)
	assert_float(glitch.severity()).is_equal(0.0)


func test_a_bigger_kick_survives_a_smaller_one_landing_on_top_of_it() -> void:
	var glitch: HudGlitch = auto_free(HudGlitch.new())
	add_child(glitch)
	glitch.hit(0.9)
	glitch.hit(0.1)
	assert_float(glitch.severity()).is_equal(0.9)
