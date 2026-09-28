extends GdUnitTestSuite

## A fitted Component is on the hull (docs/adr/0014): drawn there, solid, and heavy. Taken
## off, it waits in the Cradle and the hull is bare again. The ship in the game weighs 3.0
## (Main.tscn), so the ships here do too.

var _gs: GameState
var _station: SpaceStation

func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	add_child(_gs)
	_station = auto_free(load("res://entities/structures/SpaceStation.tscn").instantiate()) as SpaceStation
	add_child(_station)
	InventoryManager.clear_inventory()
	await get_tree().process_frame

func after_test() -> void:
	InventoryManager.clear_inventory()

func _ship() -> Ship:
	var ship := auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	ship.mass = 3.0
	add_child(ship)
	return ship

func _fit_bay() -> void:
	_gs.cradled = PackedStringArray([Components.CARGO_BAY])
	Cradle.find(get_tree()).fit()

func _art(ship: Ship) -> Node:
	return ship.get_node_or_null("Body/" + FittedParts.ART + "/" + Components.CARGO_BAY)

# --- on the hull ---

func test_a_new_ship_wears_nothing() -> void:
	var ship := _ship()
	assert_object(_art(ship)).is_null()
	assert_bool(FittedParts.wears(ship, Components.CARGO_BAY)).is_false()
	assert_float(ship.handling()).is_equal(1.0)

func test_the_fitted_bay_is_drawn_and_solid() -> void:
	var ship := _ship()
	_fit_bay()
	assert_object(_art(ship)).is_not_null()
	assert_bool(FittedParts.wears(ship, Components.CARGO_BAY)).is_true()
	assert_array(Array(ship.fitted())).contains_exactly([Components.CARGO_BAY])

func test_the_fitted_bay_is_heavy() -> void:
	var ship := _ship()
	_fit_bay()
	assert_float(ship.mass).is_equal_approx(3.35, 0.0001)
	assert_float(ship.turn_ratio()).override_failure_message("slower to turn").is_less(1.0)
	assert_float(ship.turn_ratio()).is_greater(0.9)

func test_handling_loses_one_segment_of_eight() -> void:
	var ship := _ship()
	var bay := PackedStringArray([Components.CARGO_BAY])
	assert_int(ShipPage._segments(ship.handling(PackedStringArray()))).is_equal(8)
	assert_int(ShipPage._segments(ship.handling(bay))).is_equal(7)

func test_refitting_does_not_stack_parts() -> void:
	var ship := _ship()
	_fit_bay()
	ship.refit(_gs)
	ship.refit(_gs)
	assert_int(ship.get_node("Body/" + FittedParts.ART).get_child_count()).is_equal(1)
	var colliders := ship.get_children().filter(func(c: Node) -> bool: return String(c.name).begins_with(FittedParts.COLLIDER_PREFIX))
	assert_int(colliders.size()).is_equal(1)
	assert_float(ship.mass).is_equal_approx(3.35, 0.0001)

# --- taking it off ---

func test_stowing_puts_the_bay_back_in_the_cradle() -> void:
	var ship := _ship()
	_fit_bay()
	assert_bool(Cradle.find(get_tree()).stow(Components.CARGO_BAY)).is_true()
	assert_array(_gs.cradled).contains_exactly([Components.CARGO_BAY])
	assert_array(_gs.fitted()).is_empty()
	assert_bool(_gs.progress.holds(Progress.FITTED_COMPONENTS, Components.CARGO_BAY)) \
		.override_failure_message("the ledger never goes backwards").is_true()
	assert_object(_art(ship)).is_null()
	assert_float(ship.mass).is_equal(3.0)
	assert_float(ship.max_cargo_weight).override_failure_message("the only hold can come off").is_equal(0.0)

func test_stowing_what_is_not_fitted_does_nothing() -> void:
	_ship()
	assert_bool(Cradle.find(get_tree()).stow(Components.CARGO_BAY)).is_false()
	assert_array(_gs.cradled).is_empty()

func test_it_fits_again_after_stowing() -> void:
	var ship := _ship()
	_fit_bay()
	Cradle.find(get_tree()).stow(Components.CARGO_BAY)
	Cradle.find(get_tree()).fit(Components.CARGO_BAY)
	assert_array(_gs.fitted()).contains_exactly([Components.CARGO_BAY])
	assert_float(ship.max_cargo_weight).is_equal(50.0)

func test_nothing_else_shares_its_place_yet() -> void:
	_ship()
	_gs.cradled = PackedStringArray([Components.CARGO_BAY])
	assert_str(Cradle.find(get_tree()).displaces(Components.CARGO_BAY)).is_empty()

func test_a_new_game_takes_the_parts_off() -> void:
	var ship := _ship()
	_fit_bay()
	_gs.reset_all_state()
	ship.reset_to_initial_state()
	assert_object(_art(ship)).is_null()
	assert_bool(FittedParts.wears(ship, Components.CARGO_BAY)).is_false()
	assert_float(ship.mass).is_equal(3.0)

# --- the shape ---

func test_the_fitted_bay_never_reaches_aft_of_the_hull() -> void:
	# The docked ship clears SR-7's port pad by about 2 px (docs/adr/0014)
	var ship := _ship()
	var hull := Freight.bounds(ship._hull_outline())
	var bay := Freight.bounds(Components.fitted_outline(Components.CARGO_BAY))
	assert_float(bay.position.x).is_greater_equal(hull.position.x)

func test_an_abandoned_hull_keeps_drawing_its_parts() -> void:
	var ship := _ship()
	var bare := DerelictShip.spawn(self, ship.ship_polygon, [] as Array[String], Vector2(200, 0),
		Vector2.ZERO, 0.0, 0.0, DerelictShip.HITS)
	auto_free(bare)
	_fit_bay()
	var wearing := DerelictShip.spawn(self, ship.ship_polygon, [] as Array[String], Vector2(-200, 0),
		Vector2.ZERO, 0.0, 0.0, DerelictShip.HITS)
	auto_free(wearing)
	await get_tree().process_frame
	var polys := func(d: DerelictShip) -> int: return d.find_children("*", "Polygon2D", true, false).size()
	assert_int(polys.call(wearing)).is_greater(polys.call(bare))
