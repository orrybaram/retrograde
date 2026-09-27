extends GdUnitTestSuite

## SR-7's dish coming back on the air (CommDish.ping) puts the hauler down on Veld on the
## minimap as a ping, held on the rim for its bearing, until the ship flies close enough to
## name it.

var _gs: GameState

func before_test() -> void:
	_gs = auto_free(GameState.new())
	add_child(_gs)

func _wreck() -> HaulerWreck:
	var veld := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	veld.name = "Veld"
	veld.radius = 2400.0
	veld.enable_orbiting = false
	add_child(veld)
	var wreck: HaulerWreck = auto_free(HaulerWreck.new())
	wreck.persist = false
	veld.add_child(wreck)
	wreck.set_process(false)  # driven by hand
	return wreck


func test_nothing_on_the_scope_before_the_dish_pings() -> void:
	_gs.core_started = true
	var t := HaulerWreckMinimapTarget.new(_wreck())
	assert_bool(t.is_minimap_visible()).is_false()


func test_the_dish_ping_puts_it_on_the_scope() -> void:
	_gs.core_started = true
	var wreck := _wreck()
	var t := HaulerWreckMinimapTarget.new(wreck)
	wreck.on_dish_ping()
	assert_bool(t.is_minimap_visible()).is_true()
	assert_bool(t.is_ping()).is_true()
	assert_bool(t.pins_to_edge()).override_failure_message("gives the bearing from anywhere").is_true()
	assert_vector(t.get_minimap_position()).is_equal(wreck.global_position)


func test_it_hears_the_dish_from_across_the_system() -> void:
	_gs.core_started = true
	var wreck := _wreck()
	var dish: CommDish = auto_free(CommDish.new())
	dish.add_child(Polygon2D.new())  # a part to glow
	add_child(dish)
	dish.global_position = wreck.global_position + Vector2(22000, 0)  # SR-7 to Veld's ground
	dish.ping()
	assert_bool(wreck.heard).override_failure_message("an answer, not instant").is_false()
	assert_float(CommDish.DISH_ANSWER_DELAY).is_less(StationPower.PING_WATCH)
	await await_millis(int(CommDish.DISH_ANSWER_DELAY * 1000.0) + 200)
	assert_bool(wreck.heard).is_true()


func test_it_goes_quiet_once_identified() -> void:
	_gs.core_started = true
	var wreck := _wreck()
	var t := HaulerWreckMinimapTarget.new(wreck)
	wreck.on_dish_ping()
	wreck.identify_if_near(wreck.global_position)
	assert_bool(t.is_minimap_visible()).is_false()


func test_a_load_after_the_cold_start_has_it_pinging() -> void:
	_gs.core_started = true
	var wreck := _wreck()
	EventBus.planets_restored.emit()
	assert_bool(HaulerWreckMinimapTarget.new(wreck).is_minimap_visible()).is_true()


func test_a_new_game_takes_it_off_the_scope() -> void:
	var wreck := _wreck()
	wreck.on_dish_ping()
	EventBus.planets_restored.emit()
	assert_bool(wreck.heard).is_false()
