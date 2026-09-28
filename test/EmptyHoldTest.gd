extends GdUnitTestSuite

## A new game starts with no hold at all (docs/OPENING.md §9): a dry tank, no hold
## readouts, and nothing - scrap, derelict, container or seam - offers to harvest.

var _gs: GameState


func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	add_child(_gs)
	InventoryManager.clear_inventory()


func after_test() -> void:
	InventoryManager.clear_inventory()


func _ship() -> Ship:
	var ship := auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	add_child(ship)
	# These tests put the scrap in range by hand; the cone would disown it
	ship.get_node("HarvestCone").free()
	return ship


func test_a_new_ship_has_no_hold_and_an_empty_tank() -> void:
	var ship := _ship()
	ship.reset_to_initial_state()
	assert_float(ship.drive.fuel).is_equal(0.0)
	assert_float(ship.max_cargo_weight).is_equal(0.0)
	assert_bool(ship.has_hold()).is_false()
	# Nothing to fill is not full
	assert_bool(ship.is_cargo_full()).is_false()


## Puts `ship` in range of `node`, revealed, and runs one in-range tick. Returns whether it
## offered to harvest.
func _offers_harvest(node: ScrapNode, ship: Ship) -> bool:
	node.amount = 1
	node.reveal(false)
	node._ship_in_range = ship
	node._state_machine.change_state("ScrapInRangeState")
	var offered := [false]
	node.can_harvest_changed.connect(func(can: bool) -> void: offered[0] = can)
	node._state_machine.current_state.process(0.0)
	return offered[0]


func _scrap_node(scene: String) -> ScrapNode:
	var node := auto_free(load("res://entities/resources/%s.tscn" % scene).instantiate()) as ScrapNode
	add_child(node)
	await get_tree().process_frame
	return node


func test_scrap_with_no_hold_is_revealed_but_offers_no_harvest() -> void:
	var ship := _ship()
	var scrap := await _scrap_node("Scrap1")
	assert_bool(_offers_harvest(scrap, ship)).is_false()
	assert_bool(scrap.revealed).is_true()
	assert_bool(EventBus.is_harvest_available()).is_false()


func test_a_container_with_no_hold_offers_no_harvest() -> void:
	var ship := _ship()
	var box := await _scrap_node("Container")
	assert_bool(_offers_harvest(box, ship)).is_false()


func test_a_derelict_with_no_hold_offers_no_harvest() -> void:
	var ship := _ship()
	var wreck := DerelictShip.spawn(self, ship.ship_polygon, [] as Array[String], Vector2(200, 0),
		Vector2.ZERO, 0.0, 0.0, DerelictShip.HITS)
	auto_free(wreck)
	await get_tree().process_frame
	assert_bool(_offers_harvest(wreck, ship)).is_false()


func test_scrap_harvests_once_there_is_a_hold() -> void:
	var ship := _ship()
	ship.max_cargo_weight = 50.0
	var scrap := await _scrap_node("Scrap1")
	assert_bool(_offers_harvest(scrap, ship)).is_true()
	scrap._state_machine.change_state("ScrapIdleState")


func test_a_seam_with_no_hold_offers_no_harvest() -> void:
	var planet := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	planet.radius = 400.0
	planet.enable_orbiting = false
	add_child(planet)
	var ore: OreDeposit = planet.get_ore_deposits()[0]
	_gs.mark_planet_scanned(planet.save_key())
	ore.refresh()
	var ship := _ship()
	ship.global_position = ore.global_position + ore.normal() * 20.0
	ship.set_meta("pending_ore", ore)
	ship.state_machine.change_state("PlanetLandedState")
	var state := ship.state_machine.current_state as PlanetLandedState
	assert_str(state.prompt_text()).is_equal("")
	ship.max_cargo_weight = 50.0
	assert_str(state.prompt_text()).is_equal(EventBus.action_prompt("HARVEST"))


func test_the_log_has_no_hold_row_without_a_hold() -> void:
	var ship := _ship()
	_gs.add_to_group("game_state")
	var tab := auto_free(ShipTab.new()) as ShipTab
	add_child(tab)
	tab.refresh()
	assert_bool(tab._hold_row.visible).is_false()
	ship.max_cargo_weight = 50.0
	tab.refresh()
	assert_bool(tab._hold_row.visible).is_true()
	# The refresh queues its old rows for freeing
	await get_tree().process_frame
